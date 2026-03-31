package com.sevacare.tenant.service;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ReferenceDataService {

    private final JdbcTemplate jdbcTemplate;

    public ReferenceDataService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public List<String> listSpecializations() {
        return jdbcTemplate.query(
                "SELECT specialization_name FROM public.specialization_master WHERE active = true ORDER BY display_order ASC",
                (rs, rowNum) -> rs.getString(1)
        );
    }

    @Transactional(readOnly = true)
    public List<String> listCities() {
        return jdbcTemplate.query(
                "SELECT city_name FROM public.city_master WHERE active = true ORDER BY display_order ASC",
                (rs, rowNum) -> rs.getString(1)
        );
    }
}
