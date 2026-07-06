package com.sevacare.patient.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.patient.entity.DoctorReview;

public interface DoctorReviewRepository extends JpaRepository<DoctorReview, Long> {

    Optional<DoctorReview> findByAppointmentPublicId(String appointmentPublicId);

    long countByDoctorPublicId(String doctorPublicId);
}
