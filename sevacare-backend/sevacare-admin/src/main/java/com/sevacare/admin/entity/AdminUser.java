package com.sevacare.admin.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "admin_user")
public class AdminUser {

    @Id
    @Column(name = "admin_public_id", nullable = false, length = 16)
    private String adminPublicId;

    @Column(name = "tenant_public_id", nullable = false, length = 16)
    private String tenantPublicId;

    @Column(name = "mobile_number", length = 24)
    private String mobileNumber;

    @Column(name = "email", length = 160)
    private String email;

    @Column(name = "name", length = 160)
    private String name;

    @Column(name = "full_name", length = 160)
    private String fullName;

    @Column(name = "active", nullable = false)
    private boolean active;

    @Column(name = "user_type", length = 16)
    private String userType;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "deletion_requested_at")
    private LocalDateTime deletionRequestedAt;

    @Column(name = "photo_base64", columnDefinition = "TEXT")
    private String photoBase64;

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

    public String getUserType() {
        return userType != null ? userType : "ADMIN";
    }

    public void setUserType(String userType) {
        this.userType = userType;
    }

    public String getAdminPublicId() {
        return adminPublicId;
    }

    public void setAdminPublicId(String adminPublicId) {
        this.adminPublicId = adminPublicId;
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

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
