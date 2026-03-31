package com.sevacare.shared.dto;

import java.time.Instant;

public record ContractResponse<T>(T data, Instant generatedAt) {

    public static <T> ContractResponse<T> of(T data) {
        return new ContractResponse<>(data, Instant.now());
    }
}
