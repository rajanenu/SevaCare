package com.sevacare.shared.dto;

import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * In-patient (IPD) rooms — the deliberately small shape behind "which patient
 * is in which room". One patient per room, admit-now only, no reservations.
 */
public final class IpdDtos {

    private IpdDtos() {
    }

    /**
     * A room and, when occupied, who is in it right now. {@code occupant*} and
     * {@code admissionId} are null for an AVAILABLE room.
     */
    public record RoomView(
            long roomId,
            String label,
            String roomType,
            String status,              // AVAILABLE | OCCUPIED
            String occupantPatientId,
            String occupantName,
            Long admissionId,
            String admittedAt           // "YYYY-MM-DD HH:MM" or null
    ) {
    }

    public record RoomCollection(List<RoomView> rooms) {
    }

    public record CreateRoomRequest(
            @NotBlank String label,
            String roomType
    ) {
    }

    /** A live in-patient: who, where, since when. */
    public record AdmissionView(
            long admissionId,
            String patientPublicId,
            String patientName,
            String mobileNumber,
            String bloodGroup,
            long roomId,
            String roomLabel,
            String status,              // ADMITTED | DISCHARGED
            String admittedAt,
            String dischargedAt,
            String notes
    ) {
    }

    public record AdmissionCollection(List<AdmissionView> admissions) {
    }

    public record AdmitRequest(
            @NotBlank String patientPublicId,
            @NotNull Long roomId,
            String notes
    ) {
    }
}
