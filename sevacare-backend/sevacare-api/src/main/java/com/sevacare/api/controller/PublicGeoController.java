package com.sevacare.api.controller;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sevacare.shared.dto.ContractResponse;

/**
 * Server-side reverse-geocoding proxy.
 *
 * The Flutter mobile app resolves coordinates → place name with the native
 * geocoder. On web and desktop the plugin has no implementation, and the client
 * cannot call OpenStreetMap Nominatim directly: Nominatim returns no
 * {@code Access-Control-Allow-Origin} header (so browsers block the response)
 * and its usage policy requires a {@code User-Agent} that browsers forbid
 * setting. This endpoint performs the lookup on the server — no CORS problem,
 * proper User-Agent — and is reachable under the public, CORS-enabled prefix.
 */
@RestController
@RequestMapping("/api/v1/public/geo")
public class PublicGeoController {

    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();
    private static final ObjectMapper MAPPER = new ObjectMapper();

    public record ReverseGeoResponse(String locality, String pincode) {}

    @GetMapping("/reverse")
    public ContractResponse<ReverseGeoResponse> reverse(
            @RequestParam double lat,
            @RequestParam double lng) {
        try {
            String url = "https://nominatim.openstreetmap.org/reverse?format=jsonv2"
                    + "&lat=" + lat + "&lon=" + lng + "&zoom=14&addressdetails=1";
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .header("User-Agent", "SevaCare/1.0 (support@sevacare.in)")
                    .header("Accept", "application/json")
                    .timeout(Duration.ofSeconds(8))
                    .GET()
                    .build();
            HttpResponse<String> resp = HTTP.send(request, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() != 200) {
                return ContractResponse.of(new ReverseGeoResponse(null, null));
            }
            JsonNode address = MAPPER.readTree(resp.body()).path("address");
            String locality = firstNonBlank(
                    text(address, "city"),
                    text(address, "town"),
                    text(address, "village"),
                    text(address, "suburb"),
                    text(address, "municipality"),
                    text(address, "county"));
            String pincode = text(address, "postcode");
            return ContractResponse.of(new ReverseGeoResponse(locality, pincode));
        } catch (Exception e) {
            // Never fail the caller — the client falls back to manual search.
            return ContractResponse.of(new ReverseGeoResponse(null, null));
        }
    }

    private static String text(JsonNode node, String field) {
        JsonNode v = node.path(field);
        return v.isMissingNode() || v.isNull() ? null : v.asText();
    }

    private static String firstNonBlank(String... values) {
        for (String v : values) {
            if (v != null && !v.isBlank()) return v;
        }
        return null;
    }
}
