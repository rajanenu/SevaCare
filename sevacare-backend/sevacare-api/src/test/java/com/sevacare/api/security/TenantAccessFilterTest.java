package com.sevacare.api.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/**
 * The one line that stands between one hospital and another hospital's patient
 * records. Pure, so it is tested without a servlet container, a database or a
 * login.
 */
class TenantAccessFilterTest {

    @Test
    void a_session_may_touch_its_own_tenant() {
        assertThat(TenantAccessFilter.isCrossTenant("T-1013", "T-1013")).isFalse();
    }

    @Test
    void a_session_may_not_touch_another_tenant() {
        // The breach this filter exists for: a real admin token from T-1013,
        // replayed with T-1017 in the X-Tenant-Id header, used to return T-1017's
        // patient list.
        assertThat(TenantAccessFilter.isCrossTenant("T-1013", "T-1017")).isTrue();
    }

    @Test
    void tenant_id_case_and_padding_do_not_open_a_door() {
        assertThat(TenantAccessFilter.isCrossTenant("t-1013", "T-1013")).isFalse();
        assertThat(TenantAccessFilter.isCrossTenant(" T-1013 ", "T-1013")).isFalse();
    }

    @Test
    void routes_with_no_tenant_are_not_this_filters_business() {
        // Public discovery, /auth/** and /platform-admin/** never resolve a tenant.
        assertThat(TenantAccessFilter.isCrossTenant("T-1013", null)).isFalse();
        assertThat(TenantAccessFilter.isCrossTenant(null, null)).isFalse();
    }

    @Test
    void a_token_carrying_no_tenant_reaches_no_tenant() {
        assertThat(TenantAccessFilter.isCrossTenant(null, "T-1013")).isTrue();
    }

    @Test
    void a_platform_admin_token_is_not_a_skeleton_key() {
        // Their tenant claim is the sentinel "platform", which is no customer's
        // schema. Operator endpoints live under /platform-admin, which carries no
        // tenant context at all — so denying this costs nothing and means a stolen
        // operator token cannot be aimed at a customer's records.
        assertThat(TenantAccessFilter.isCrossTenant("platform", "T-1013")).isTrue();
    }
}
