package com.sevacare.pharmacy;

import static com.tngtech.archunit.base.DescribedPredicate.alwaysTrue;
import static com.tngtech.archunit.core.domain.JavaClass.Predicates.resideInAPackage;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import org.junit.jupiter.api.Test;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.dependencies.SlicesRuleDefinition;

/**
 * The monolith stays modular because CI says so, not because everyone remembers.
 *
 * <p>These rules are cheap to satisfy while the module is empty and expensive to
 * retrofit once it is not, which is exactly why they land in Phase 0 rather than
 * after the first context is written.
 */
class PharmacyBoundaryTest {

    private static final JavaClasses PHARMACY = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("com.sevacare.pharmacy");

    /**
     * A context may not reach into another context's internals. It may import a
     * sibling's {@code spi} package (read-only lookups by public id), and it
     * learns about state changes by subscribing to domain events.
     *
     * <p>This is the rule that keeps the seven contexts extractable into separate
     * services later without a rewrite: nothing joins across a boundary.
     */
    @Test
    void contexts_do_not_depend_on_each_others_internals() {
        ArchRule rule = SlicesRuleDefinition.slices()
                .matching("com.sevacare.pharmacy.(*)..")
                .should().notDependOnEachOther()
                .ignoreDependency(alwaysTrue(), resideInAPackage("..spi.."))
                // An empty module is a legitimate starting state, not a failure.
                .allowEmptyShould(true);

        rule.check(PHARMACY);
    }

    /**
     * Pharmacy hears about consultations and prescriptions through events, never
     * by calling into the modules that own them. A direct dependency here would
     * turn "pharmacy reacts to a prescription" into "pharmacy is coupled to the
     * consult transaction", which is the coupling the outbox exists to avoid.
     */
    @Test
    void pharmacy_does_not_depend_on_sibling_feature_modules() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("com.sevacare.pharmacy..")
                .should().dependOnClassesThat()
                .resideInAnyPackage(
                        "com.sevacare.patient..",
                        "com.sevacare.doctor..",
                        "com.sevacare.admin..")
                .allowEmptyShould(true);

        rule.check(PHARMACY);
    }

    /**
     * Entities are the domain's nouns; they must not know about the services that
     * manipulate them or the controllers that expose them.
     */
    @Test
    void entities_do_not_depend_on_services_or_controllers() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("..pharmacy..entity..")
                .should().dependOnClassesThat()
                .resideInAnyPackage("..pharmacy..service..", "..pharmacy..api..")
                .allowEmptyShould(true);

        rule.check(PHARMACY);
    }

    /**
     * An {@code spi} is a contract, not a window. If it hands out JPA entities or
     * repositories, callers end up depending on this context's table shape and the
     * boundary is a boundary in name only — the "quick join" that quietly turns two
     * services back into one shared database. SPIs speak in public ids and DTOs.
     */
    @Test
    void spi_does_not_leak_internals() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("..pharmacy..spi..")
                .should().dependOnClassesThat()
                .resideInAnyPackage("..pharmacy..entity..", "..pharmacy..repository..")
                .allowEmptyShould(true);

        rule.check(PHARMACY);
    }
}
