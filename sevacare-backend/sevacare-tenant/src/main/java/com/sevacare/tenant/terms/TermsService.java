package com.sevacare.tenant.terms;

import java.time.LocalDateTime;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.dto.TermsDtos;
import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;

/**
 * The one place that knows what SevaCare's terms say, which version is in force,
 * and which tenants have accepted it.
 *
 * <p>Consent is stored on {@code tenant_registry} — version, moment, and the name of
 * the person who accepted — because a hospital or a medical store may be asked years
 * later what it agreed to. A tenant that has accepted nothing, or accepted an older
 * version, is asked once when its owner next signs in; nobody is assumed to have
 * agreed to words they were never shown.
 *
 * <p>Bumping {@link #CURRENT_VERSION} is therefore a deliberate act: it re-asks every
 * customer. Fix a typo without touching the version; change what the agreement
 * <em>means</em>, and change the version.
 */
@Service
public class TermsService {

    private static final Logger log = LoggerFactory.getLogger(TermsService.class);

    public static final String CURRENT_VERSION = "1.0";
    private static final String EFFECTIVE_DATE = "2026-07-12";

    private static final TermsDtos.TermsDocument DOCUMENT = new TermsDtos.TermsDocument(
            CURRENT_VERSION,
            EFFECTIVE_DATE,
            "SevaCare is software that helps a hospital, clinic or medical store organise its "
            + "own work. Your records stay yours: we do not change them, we do not sell them, "
            + "and we do not audit them on your behalf.",
            List.of(
                    new TermsDtos.TermsSection("What SevaCare is", List.of(
                            "SevaCare is a record-keeping and scheduling tool. It helps you register patients, "
                            + "book appointments, write prescriptions, keep stock and raise bills, so that the "
                            + "work your team already does is faster and better organised.",
                            "SevaCare does not practise medicine, does not dispense medicine and takes no "
                            + "clinical or commercial decision for you. Every entry in this application is made "
                            + "by you or by your staff, and stands as your record."
                    )),
                    new TermsDtos.TermsSection("Your data belongs to you", List.of(
                            "We store and process your data for one purpose only: to run this service for you.",
                            "We do not sell your data, we do not share it with third parties for marketing, and "
                            + "we do not alter, edit or manipulate your patient records, stock ledger or bills. "
                            + "You can ask for an export, or for deletion, at any time."
                    )),
                    new TermsDtos.TermsSection("What you are responsible for", List.of(
                            "You are responsible for the accuracy of everything entered into SevaCare — patient "
                            + "details, prescriptions, batch numbers, expiry dates, purchase prices, MRP, GST "
                            + "rates and bill amounts.",
                            "SevaCare shows you what was entered. It is not an auditor and does not verify your "
                            + "figures against reality. SevaCare is not responsible for data mismatches, "
                            + "stock differences, tax or audit outcomes, or any loss arising from an entry that "
                            + "was wrong, late or missing."
                    )),
                    new TermsDtos.TermsSection("Licences and statutory duties stay with you", List.of(
                            "Your drug licence, your Schedule H register, your medical council obligations, your "
                            + "GST returns and every other statutory duty remain yours. SevaCare can help you keep "
                            + "the records those duties require, but complying with them is your responsibility."
                    )),
                    new TermsDtos.TermsSection("Availability and backups", List.of(
                            "We work to keep the service available and its data safe, and we take regular backups. "
                            + "We cannot promise uninterrupted service, and we recommend you export the reports that "
                            + "matter to you and keep your own copies."
                    )),
                    new TermsDtos.TermsSection("Accounts and access", List.of(
                            "Sign-in is by the mobile number registered with us. Keep those numbers and the devices "
                            + "they belong to secure. Anyone you add as an admin, doctor, front-desk or counter user "
                            + "acts on your behalf, and what they enter is your record."
                    )),
                    new TermsDtos.TermsSection("Fees and changes to these terms", List.of(
                            "Charges, if any, are what was agreed with you in writing when you were onboarded.",
                            "If these terms change in any way that matters, the new version appears in this "
                            + "application and we ask you to accept it before you carry on. You can read the "
                            + "current version at any time from Help, or from your profile."
                    ))
            ));

    private final TenantRegistryRepository tenantRegistryRepository;

    public TermsService(TenantRegistryRepository tenantRegistryRepository) {
        this.tenantRegistryRepository = tenantRegistryRepository;
    }

    public TermsDtos.TermsDocument document() {
        return DOCUMENT;
    }

    @Transactional(readOnly = true)
    public TermsDtos.TermsAcceptanceView acceptance(String tenantPublicId) {
        TenantRegistry tenant = tenantRegistryRepository.findById(tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Unknown tenant: " + tenantPublicId));
        return toView(tenant);
    }

    @Transactional
    public TermsDtos.TermsAcceptanceView accept(String tenantPublicId, String acceptedBy) {
        TenantRegistry tenant = tenantRegistryRepository.findById(tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Unknown tenant: " + tenantPublicId));
        stamp(tenant, acceptedBy);
        TenantRegistry saved = tenantRegistryRepository.save(tenant);
        log.info("terms_accepted tenantPublicId={} version={} acceptedBy={}",
                tenantPublicId, CURRENT_VERSION, saved.getTermsAcceptedBy());
        return toView(saved);
    }

    /**
     * Consent given to the SevaCare team at onboarding, before the customer has any
     * login of their own. Recorded against the tenant so the same question is not put
     * to them again on their first sign-in.
     */
    public void stampOnboardingAcceptance(TenantRegistry tenant, String acceptedBy) {
        stamp(tenant, acceptedBy);
    }

    private void stamp(TenantRegistry tenant, String acceptedBy) {
        String who = acceptedBy == null || acceptedBy.isBlank() ? "Tenant admin" : acceptedBy.trim();
        tenant.setTermsVersion(CURRENT_VERSION);
        tenant.setTermsAcceptedAt(LocalDateTime.now());
        tenant.setTermsAcceptedBy(who.length() > 160 ? who.substring(0, 160) : who);
    }

    private TermsDtos.TermsAcceptanceView toView(TenantRegistry tenant) {
        String accepted = tenant.getTermsVersion();
        return new TermsDtos.TermsAcceptanceView(
                tenant.getTenantPublicId(),
                CURRENT_VERSION,
                accepted,
                tenant.getTermsAcceptedAt(),
                tenant.getTermsAcceptedBy(),
                CURRENT_VERSION.equals(accepted));
    }
}
