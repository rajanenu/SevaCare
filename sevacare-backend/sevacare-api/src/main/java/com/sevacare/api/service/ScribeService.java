package com.sevacare.api.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.sevacare.shared.tenant.TenantContext;

/**
 * The voice scribe: a doctor dictates the consult in whatever mix of English,
 * Hindi or Telugu they actually speak, the device's speech recognition turns it
 * into text, and this service turns that text into a structured prescription
 * draft the consultation form pre-fills. The doctor reviews and edits before
 * anything is saved or sent — the model drafts, the doctor authors.
 *
 * <p>Design notes:
 * <ul>
 *   <li>Only the transcript text ever leaves the device — no audio is uploaded
 *       or stored anywhere. The request/response are processed transiently and
 *       never persisted here (the audit log records the access, not the text).</li>
 *   <li>Follows the WhatsAppService house pattern: raw {@code java.net.http}
 *       against the provider's REST API, inert until credentials exist.
 *       Without {@code SEVACARE_ANTHROPIC_API_KEY} the endpoint answers 503 and
 *       {@code /capabilities} reports {@code voiceScribe: false}, so the app
 *       never shows the mic.</li>
 *   <li>The response is forced into a JSON schema by the API itself
 *       ({@code output_config.format}), so parsing cannot meet malformed JSON.</li>
 *   <li>For a tenant with a pharmacy, each drafted medicine is matched against
 *       the store's own catalog, so the prescription that leaves the consult is
 *       dispensable at their counter without retyping.</li>
 * </ul>
 */
@Service
public class ScribeService {

    private static final Logger log = LoggerFactory.getLogger(ScribeService.class);

    private final ObjectMapper objectMapper;
    private final JdbcTemplate jdbcTemplate;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    @Value("${sevacare.anthropic.api-key:}")
    private String apiKey;

    @Value("${sevacare.anthropic.api-base:https://api.anthropic.com}")
    private String apiBase;

    @Value("${sevacare.anthropic.scribe-model:claude-opus-4-8}")
    private String model;

    public ScribeService(ObjectMapper objectMapper, JdbcTemplate jdbcTemplate) {
        this.objectMapper = objectMapper;
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean isConfigured() {
        return apiKey != null && !apiKey.isBlank();
    }

    // ── Contract ─────────────────────────────────────────────────────────────

    public record ScribeRequest(String transcript, String patientContext) {
    }

    public record ScribeVitals(String bp, String pulse, String temperature, String spo2, String weight) {
    }

    /** Field names mirror the consultation form's medicine entry (and PrescriptionMedicine). */
    public record ScribeMedicine(String name, String strength, String frequency, String duration,
                                 String instructions, String skuPublicId, String matchedBrandName) {
    }

    public record ScribeDraft(String complaints, String diagnosis, ScribeVitals vitals,
                              List<ScribeMedicine> medicines, String advice, int followUpDays) {
    }

    // ── Draft ────────────────────────────────────────────────────────────────

    public ScribeDraft draft(String transcript, String patientContext) {
        if (!isConfigured()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Voice scribe is not configured on this server");
        }
        if (transcript == null || transcript.isBlank()) {
            throw new IllegalArgumentException("Transcript is required");
        }
        String trimmed = transcript.length() > 8000 ? transcript.substring(0, 8000) : transcript;

        JsonNode response = callClaude(trimmed, patientContext);
        ScribeDraft parsed = parseDraft(response);
        return withCatalogMatches(parsed);
    }

    private JsonNode callClaude(String transcript, String patientContext) {
        try {
            ObjectNode body = objectMapper.createObjectNode();
            body.put("model", model);
            body.put("max_tokens", 3000);
            body.set("thinking", objectMapper.createObjectNode().put("type", "adaptive"));
            body.put("system", SYSTEM_PROMPT);
            body.set("output_config", objectMapper.createObjectNode()
                    .set("format", objectMapper.createObjectNode()
                            .put("type", "json_schema")
                            .set("schema", objectMapper.readTree(DRAFT_SCHEMA))));
            String user = (patientContext == null || patientContext.isBlank())
                    ? transcript
                    : "Patient: " + patientContext + "\n\nDictation:\n" + transcript;
            body.set("messages", objectMapper.createArrayNode()
                    .add(objectMapper.createObjectNode().put("role", "user").put("content", user)));

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(apiBase + "/v1/messages"))
                    .timeout(Duration.ofSeconds(90))
                    .header("Content-Type", "application/json")
                    .header("x-api-key", apiKey)
                    .header("anthropic-version", "2023-06-01")
                    .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(body)))
                    .build();

            HttpResponse<String> httpResponse = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (httpResponse.statusCode() == 401 || httpResponse.statusCode() == 403) {
                log.error("scribe_auth_failed status={}", httpResponse.statusCode());
                throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                        "Voice scribe is not configured correctly");
            }
            if (httpResponse.statusCode() == 429) {
                throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                        "Scribe is busy — please try again in a moment");
            }
            if (httpResponse.statusCode() != 200) {
                log.error("scribe_provider_error status={} body={}", httpResponse.statusCode(),
                        truncate(httpResponse.body()));
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                        "Scribe could not process the dictation — please try again");
            }
            return objectMapper.readTree(httpResponse.body());
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            log.error("scribe_call_failed reason={}", e.getMessage());
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "Scribe could not process the dictation — please try again");
        }
    }

    private ScribeDraft parseDraft(JsonNode response) {
        if ("refusal".equals(response.path("stop_reason").asText())) {
            throw new IllegalArgumentException("The dictation could not be processed — please try rephrasing");
        }
        String json = null;
        for (JsonNode block : response.path("content")) {
            if ("text".equals(block.path("type").asText())) {
                json = block.path("text").asText();
                break;
            }
        }
        if (json == null || json.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Scribe returned an empty draft");
        }
        try {
            JsonNode d = objectMapper.readTree(json);
            JsonNode v = d.path("vitals");
            List<ScribeMedicine> medicines = new ArrayList<>();
            for (JsonNode m : d.path("medicines")) {
                medicines.add(new ScribeMedicine(
                        m.path("name").asText(""),
                        m.path("strength").asText(""),
                        m.path("frequency").asText(""),
                        m.path("duration").asText(""),
                        m.path("instructions").asText(""),
                        null, null));
            }
            return new ScribeDraft(
                    d.path("complaints").asText(""),
                    d.path("diagnosis").asText(""),
                    new ScribeVitals(v.path("bp").asText(""), v.path("pulse").asText(""),
                            v.path("temperature").asText(""), v.path("spo2").asText(""),
                            v.path("weight").asText("")),
                    medicines,
                    d.path("advice").asText(""),
                    d.path("followUpDays").asInt(0));
        } catch (Exception e) {
            log.error("scribe_parse_failed reason={}", e.getMessage());
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Scribe returned an unreadable draft");
        }
    }

    /**
     * For a pharmacy-enabled tenant, marries each drafted medicine to the store's
     * own catalog by brand-name prefix — so the draft the doctor confirms is the
     * SKU the counter can actually dispense. A hospital without a pharmacy simply
     * has no medicine_sku table in its schema, which the catch treats as "no match".
     */
    private ScribeDraft withCatalogMatches(ScribeDraft draft) {
        String schema = TenantContext.tenantSchema();
        if (schema == null || schema.isBlank() || draft.medicines().isEmpty()) {
            return draft;
        }
        List<ScribeMedicine> matched = new ArrayList<>();
        for (ScribeMedicine medicine : draft.medicines()) {
            String skuPublicId = null;
            String brandName = null;
            String term = firstWord(medicine.name());
            if (!term.isBlank()) {
                try {
                    Map<String, Object> row = jdbcTemplate.queryForMap(
                            "SELECT sku_public_id, brand_name FROM " + schema + ".medicine_sku " +
                            "WHERE lower(brand_name) LIKE lower(?) || '%' " +
                            "ORDER BY length(brand_name) LIMIT 1", term);
                    skuPublicId = (String) row.get("sku_public_id");
                    brandName = (String) row.get("brand_name");
                } catch (Exception ignored) {
                    // No pharmacy module, or simply no matching SKU — the draft stands on its own.
                }
            }
            matched.add(new ScribeMedicine(medicine.name(), medicine.strength(), medicine.frequency(),
                    medicine.duration(), medicine.instructions(), skuPublicId, brandName));
        }
        return new ScribeDraft(draft.complaints(), draft.diagnosis(), draft.vitals(),
                matched, draft.advice(), draft.followUpDays());
    }

    private static String firstWord(String name) {
        if (name == null) {
            return "";
        }
        String trimmed = name.trim();
        int space = trimmed.indexOf(' ');
        return space > 0 ? trimmed.substring(0, space) : trimmed;
    }

    private static String truncate(String body) {
        return body == null ? "" : body.substring(0, Math.min(body.length(), 300));
    }

    private static final String SYSTEM_PROMPT =
            "You are a medical scribe for Indian outpatient clinics. The input is a doctor's dictated " +
            "consultation note, transcribed by speech recognition. It may freely mix English, Hindi, " +
            "Telugu or other Indian languages, and use Indian prescribing shorthand (OD, BD, TDS, QID, " +
            "HS, SOS, x5d, 1-0-1 and similar).\n" +
            "Extract the dictation into the JSON schema. Rules:\n" +
            "- Write every field in concise English, expanding shorthand (BD becomes 'twice daily'; " +
            "1-0-1 becomes 'morning and night').\n" +
            "- Medicine names stay as the brand or generic name the doctor said, with the strength " +
            "(e.g. '500mg') in the strength field, not the name.\n" +
            "- Never invent a medicine, dose, vital sign or diagnosis that was not dictated. If the " +
            "speech recognition has garbled a word beyond recognition, leave it out rather than guess.\n" +
            "- A field that was not mentioned is an empty string, and followUpDays is 0 when no " +
            "follow-up was mentioned.\n" +
            "- 'complaints' is what the patient presented with; 'advice' is non-drug guidance " +
            "(rest, diet, tests to get done).";

    private static final String DRAFT_SCHEMA = """
            {
              "type": "object",
              "properties": {
                "complaints": {"type": "string"},
                "diagnosis": {"type": "string"},
                "vitals": {
                  "type": "object",
                  "properties": {
                    "bp": {"type": "string"},
                    "pulse": {"type": "string"},
                    "temperature": {"type": "string"},
                    "spo2": {"type": "string"},
                    "weight": {"type": "string"}
                  },
                  "required": ["bp", "pulse", "temperature", "spo2", "weight"],
                  "additionalProperties": false
                },
                "medicines": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "name": {"type": "string"},
                      "strength": {"type": "string"},
                      "frequency": {"type": "string"},
                      "duration": {"type": "string"},
                      "instructions": {"type": "string"}
                    },
                    "required": ["name", "strength", "frequency", "duration", "instructions"],
                    "additionalProperties": false
                  }
                },
                "advice": {"type": "string"},
                "followUpDays": {"type": "integer"}
              },
              "required": ["complaints", "diagnosis", "vitals", "medicines", "advice", "followUpDays"],
              "additionalProperties": false
            }
            """;
}
