package com.sevacare.doctor.entity;

import java.time.LocalDate;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "doctor")
public class Doctor {

    @Id
    @Column(name = "doctor_public_id", nullable = false, length = 16)
    private String doctorPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "full_name", nullable = false, length = 120)
    private String fullName;

    @Column(name = "specialty", nullable = false, length = 120)
    private String specialty;

    @Column(name = "availability", nullable = false, length = 120)
    private String availability;

    @Column(name = "fee", nullable = false, length = 32)
    private String fee;

    @Column(name = "mobile_number", length = 24)
    private String mobileNumber;

    @Column(name = "active", nullable = false)
    private boolean active;

    @Column(name = "age")
    private Integer age;

    @Column(name = "address", length = 500)
    private String address;

    @Column(name = "about_me", length = 1000)
    private String aboutMe;

    @Column(name = "available_from")
    private LocalDate availableFrom;

    @Column(name = "ready_to_look_patients")
    private Boolean readyToLookPatients;

    // SLOT, TOKEN, or BOTH — which booking modes this doctor offers to patients
    @Column(name = "booking_mode", nullable = false, length = 16)
    private String bookingMode = "BOTH";

    @Column(name = "experience_years")
    private Integer experienceYears;

    @Column(name = "qualification", length = 200)
    private String qualification;

    public String getDoctorPublicId() {
        return doctorPublicId;
    }

    public void setDoctorPublicId(String doctorPublicId) {
        this.doctorPublicId = doctorPublicId;
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

    public String getSpecialty() {
        return specialty;
    }

    public void setSpecialty(String specialty) {
        this.specialty = specialty;
    }

    public String getAvailability() {
        return availability;
    }

    public void setAvailability(String availability) {
        this.availability = availability;
    }

    public String getFee() {
        return fee;
    }

    public void setFee(String fee) {
        this.fee = fee;
    }

    public String getMobileNumber() {
        return mobileNumber;
    }

    public void setMobileNumber(String mobileNumber) {
        this.mobileNumber = mobileNumber;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
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

    public String getAboutMe() {
        return aboutMe;
    }

    public void setAboutMe(String aboutMe) {
        this.aboutMe = aboutMe;
    }

    public LocalDate getAvailableFrom() {
        return availableFrom;
    }

    public void setAvailableFrom(LocalDate availableFrom) {
        this.availableFrom = availableFrom;
    }

    public Boolean getReadyToLookPatients() {
        return readyToLookPatients;
    }

    public void setReadyToLookPatients(Boolean readyToLookPatients) {
        this.readyToLookPatients = readyToLookPatients;
    }

    public String getBookingMode() {
        return bookingMode;
    }

    public void setBookingMode(String bookingMode) {
        this.bookingMode = bookingMode;
    }

    public Integer getExperienceYears() {
        return experienceYears;
    }

    public void setExperienceYears(Integer experienceYears) {
        this.experienceYears = experienceYears;
    }

    public String getQualification() {
        return qualification;
    }

    public void setQualification(String qualification) {
        this.qualification = qualification;
    }
}
