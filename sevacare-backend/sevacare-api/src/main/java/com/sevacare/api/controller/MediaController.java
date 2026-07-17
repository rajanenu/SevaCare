package com.sevacare.api.controller;

import java.util.Optional;
import java.util.regex.Pattern;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.api.service.MediaService;

import java.time.Duration;

/**
 * Serves content-addressed image bytes from public.media. The path is under
 * /api/v1/public so it inherits the existing permit-all + tenant-header-skip
 * wiring, and it is deliberately public: the object is named by the SHA-256 of
 * its own bytes, a 256-bit value that only ever appears inside an authenticated
 * response — unguessable, exactly like a signed object-store URL — and the same
 * treatment the tenant hero image (a public login background) already gets.
 *
 * Because a sha can never point at different bytes, the response is immutable:
 * one download per client, then a 304 or a browser cache hit forever.
 */
@RestController
@RequestMapping("/api/v1/public/media")
public class MediaController {

    private static final Pattern SHA256 = Pattern.compile("^[0-9a-f]{64}$");

    private final MediaService mediaService;

    public MediaController(MediaService mediaService) {
        this.mediaService = mediaService;
    }

    @GetMapping("/{sha256}")
    public ResponseEntity<Resource> get(
            @PathVariable String sha256,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {

        if (sha256 == null || !SHA256.matcher(sha256).matches()) {
            return ResponseEntity.notFound().build();
        }

        String etag = "\"" + sha256 + "\"";
        // The content is immutable, so a matching If-None-Match is always current.
        if (etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(304)
                    .eTag(etag)
                    .cacheControl(immutable())
                    .build();
        }

        Optional<MediaService.MediaBlob> blob = mediaService.get(sha256);
        if (blob.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        MediaService.MediaBlob media = blob.get();
        return ResponseEntity.ok()
                .eTag(etag)
                .cacheControl(immutable())
                .contentType(parseType(media.contentType()))
                .contentLength(media.bytes().length)
                .body(new ByteArrayResource(media.bytes()));
    }

    private static CacheControl immutable() {
        return CacheControl.maxAge(Duration.ofDays(365)).cachePublic().immutable();
    }

    private static MediaType parseType(String contentType) {
        try {
            return MediaType.parseMediaType(contentType);
        } catch (RuntimeException invalid) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }
}
