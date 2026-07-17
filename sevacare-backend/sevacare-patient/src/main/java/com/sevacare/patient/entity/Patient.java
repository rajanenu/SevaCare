package com.sevacare.patient.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "patient")
public class Patient {

    @Id
    @Column(name = "patient_public_id", nullable = false, length = 16)
    private String patientPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "full_name", nullable = false, length = 120)
    private String fullName;

    @Column(name = "mobile_number", nullable = false, length = 24)
    private String mobileNumber;

    @Column(name = "status", nullable = false, length = 24)
    private String status;

    @Column(name = "email", length = 120)
    private String email;

    @Column(name = "gender", length = 10)
    private String gender;

    @Column(name = "age")
    private Integer age;

    @Column(name = "address", length = 500)
    private String address;

    @Column(name = "blood_group", length = 8)
    private String bloodGroup;

    // ABDM: linked Ayushman Bharat Health Account, when the patient has one.
    @Column(name = "abha_number", length = 17)
    private String abhaNumber;

    @Column(name = "abha_address", length = 64)
    private String abhaAddress;

    @Column(name = "deletion_requested_at")
    private LocalDateTime deletionRequestedAt;

    @Column(name = "photo_base64", columnDefinition = "TEXT")
    private String photoBase64;

    // Content-addressed reference into public.media; supersedes photo_base64.
    @Column(name = "photo_media_sha", length = 64)
    private String photoMediaSha;

    public LocalDateTime getDeletionRequestedAt() {
        return deletionRequestedAt;
    }

    public void setDeletionRequestedAt(LocalDateTime deletionRequestedAt) {
        this.deletionRequestedAt = deletionRequestedAt;
    }

    public String getPhotoBase64() {
        return photoBase64;
    }

    public void setPhotoBase64(String photoBase64) {
        this.photoBase64 = photoBase64;
    }

    public String getPhotoMediaSha() {
        return photoMediaSha;
    }

    public void setPhotoMediaSha(String photoMediaSha) {
        this.photoMediaSha = photoMediaSha;
    }

    public String getPatientPublicId() {
        return patientPublicId;
    }

    public void setPatientPublicId(String patientPublicId) {
        this.patientPublicId = patientPublicId;
    }

    public String getTenantPublicId() {
        return tenantPublicId;
    }

    public void setTenantPublicId(String tenantPublicId) {
        this.tenantPublicId = tenantPublicId;
    }

    public String getFullName() {
        return fullName;
    }

    public void setFullName(String fullName) {
        this.fullName = fullName;
    }

    public String getMobileNumber() {
        return mobileNumber;
    }

    public void setMobileNumber(String mobileNumber) {
        this.mobileNumber = mobileNumber;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getGender() {
        return gender;
    }

    public void setGender(String gender) {
        this.gender = gender;
    }

    public Integer getAge() {
        return age;
    }

    public void setAge(Integer age) {
        this.age = age;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getBloodGroup() {
        return bloodGroup;
    }

    public void setBloodGroup(String bloodGroup) {
        this.bloodGroup = bloodGroup;
    }
}
