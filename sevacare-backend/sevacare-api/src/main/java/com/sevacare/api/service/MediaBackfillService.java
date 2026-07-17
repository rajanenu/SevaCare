package com.sevacare.api.service;

import java.util.List;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

/**
 * Moves legacy base64 image columns into the deduplicated public.media store and
 * leaves a content-addressed reference behind. Idempotent and re-runnable: every
 * query only touches rows that still have base64 and no media_sha yet, so a
 * second instance (or a second tick) finds nothing left to do. Runs once in the
 * background at boot and is also exposed through /internal/jobs so the Cloud
 * Scheduler cron finishes anything a throttled instance left behind.
 *
 * Legacy base64 is nulled as each row migrates, reclaiming the TEXT column; the
 * bytes now live once in media no matter how many rows shared the same image.
 */
@Service
public class MediaBackfillService {

    private static final Logger log = LoggerFactory.getLogger(MediaBackfillService.class);
    private static final Pattern TENANT_SCHEMA = Pattern.compile("^tenant_t_[0-9a-z_]+$");
    private static final int BATCH = 200;

    private final JdbcTemplate jdbc;
    private final MediaService mediaService;

    public MediaBackfillService(JdbcTemplate jdbc, MediaService mediaService) {
        this.jdbc = jdbc;
        this.mediaService = mediaService;
    }

    @Async
    @EventListener(ApplicationReadyEvent.class)
    public void onBoot() {
        try {
            backfillAll();
        } catch (Exception e) {
            // Never let a backfill hiccup affect startup; the cron will retry.
            log.warn("media_backfill_boot_failed", e);
        }
    }

    /** Migrate every remaining base64 image (hero + per-tenant photos) into media. */
    public void backfillAll() {
        int hero = backfillHeroImages();
        int photos = backfillTenantPhotos();
        if (hero > 0 || photos > 0) {
            log.info("media_backfill_done hero={} photos={}", hero, photos);
        }
    }

    private int backfillHeroImages() {
        int moved = 0;
        while (true) {
            List<String[]> rows = jdbc.query(
                    "SELECT tenant_public_id, hero_image_base64 FROM public.tenant_registry " +
                            "WHERE hero_image_base64 IS NOT NULL AND hero_image_media_sha IS NULL LIMIT " + BATCH,
                    (rs, i) -> new String[] { rs.getString(1), rs.getString(2) });
            if (rows.isEmpty()) {
                break;
            }
            for (String[] row : rows) {
                String sha = mediaService.putBase64(row[1]);
                jdbc.update(
                        "UPDATE public.tenant_registry " +
                                "SET hero_image_media_sha = ?, hero_image_base64 = NULL, hero_image_content_type = NULL " +
                                "WHERE tenant_public_id = ?",
                        sha, row[0]);
                moved++;
            }
            if (rows.size() < BATCH) {
                break;
            }
        }
        return moved;
    }

    private int backfillTenantPhotos() {
        List<String> schemas = jdbc.queryForList(
                "SELECT tenant_schema FROM public.tenant_registry WHERE tenant_schema IS NOT NULL", String.class);
        int moved = 0;
        for (String schema : schemas) {
            if (schema == null || !TENANT_SCHEMA.matcher(schema).matches()) {
                continue; // never interpolate an unvetted identifier
            }
            for (String table : List.of("patient", "doctor", "admin_user")) {
                moved += backfillPhotoTable(schema, table);
            }
        }
        return moved;
    }

    private int backfillPhotoTable(String schema, String table) {
        String qualified = "\"" + schema + "\"." + table;
        int moved = 0;
        while (true) {
            List<String[]> rows;
            try {
                rows = jdbc.query(
                        "SELECT ctid::text, photo_base64 FROM " + qualified +
                                " WHERE photo_base64 IS NOT NULL AND photo_media_sha IS NULL LIMIT " + BATCH,
                        (rs, i) -> new String[] { rs.getString(1), rs.getString(2) });
            } catch (Exception missingColumn) {
                // A schema not yet migrated to V17 has no photo_media_sha column; skip it.
                return moved;
            }
            if (rows.isEmpty()) {
                break;
            }
            for (String[] row : rows) {
                String sha = mediaService.putBase64(row[1]);
                // ctid is stable within this run; the WHERE also re-checks the guard
                // so a concurrent migrator can't double-write the same row.
                jdbc.update(
                        "UPDATE " + qualified + " SET photo_media_sha = ?, photo_base64 = NULL " +
                                "WHERE ctid = ?::tid AND photo_media_sha IS NULL",
                        sha, row[0]);
                moved++;
            }
            if (rows.size() < BATCH) {
                break;
            }
        }
        return moved;
    }
}
