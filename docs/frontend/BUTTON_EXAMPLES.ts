// Button Design System - Quick Reference & Examples
// SevaCare Frontend v1.0

import { PrimaryButton, SecondaryButton, DangerButton, ButtonContainer } from '../components/ui';

/** ============================================
 *  BASIC SINGLE BUTTONS (Content-Based Width)
 *  ============================================ */

export function BasicButtonExamples() {
  return (
    <>
      {/* Primary Button - Auto-sized to content */}
      <PrimaryButton label="Save Changes" onPress={() => console.log('Save')} />

      {/* Primary Button - Centered */}
      <PrimaryButton label="Submit Form" onPress={() => console.log('Submit')} align="center" />

      {/* Primary Button - Full Width (when needed) */}
      <PrimaryButton label="Continue" onPress={() => console.log('Continue')} wide={true} />

      {/* Secondary Button - Auto-sized (previously had minWidth: 120) */}
      <SecondaryButton label="Learn More" onPress={() => console.log('Learn')} />

      {/* Danger Button - Outline style (default) */}
      <DangerButton label="Delete" onPress={() => console.log('Delete')} />

      {/* Danger Button - Filled style */}
      <DangerButton label="Sign Out" onPress={() => console.log('Sign Out')} filled={true} />
    </>
  );
}

/** ============================================
 *  BUTTON GROUPS (Using ButtonContainer)
 *  ============================================ */

export function ButtonGroupExamples() {
  return (
    <>
      {/* Horizontal buttons - centered layout */}
      <ButtonContainer horizontal align="center" gap={12}>
        <SecondaryButton label="Cancel" onPress={() => {}} />
        <PrimaryButton label="Save" onPress={() => {}} />
      </ButtonContainer>

      {/* Horizontal buttons - space between (footer style) */}
      <ButtonContainer horizontal align="space-between" gap={0}>
        <SecondaryButton label="← Back" onPress={() => {}} />
        <PrimaryButton label="Next →" onPress={() => {}} />
      </ButtonContainer>

      {/* Vertical buttons - left aligned */}
      <ButtonContainer horizontal={false} align="flex-start" gap={8}>
        <PrimaryButton label="Create New" onPress={() => {}} />
        <SecondaryButton label="View All" onPress={() => {}} />
      </ButtonContainer>

      {/* Vertical buttons - centered */}
      <ButtonContainer horizontal={false} align="center" gap={12}>
        <PrimaryButton label="Take Action" onPress={() => {}} />
        <SecondaryButton label="Learn More" onPress={() => {}} />
      </ButtonContainer>

      {/* Responsive wrapping buttons */}
      <ButtonContainer horizontal={true} align="center" gap={12} wrap={true}>
        <PrimaryButton label="Save" onPress={() => {}} />
        <SecondaryButton label="Draft" onPress={() => {}} />
        <DangerButton label="Delete" onPress={() => {}} />
      </ButtonContainer>
    </>
  );
}

/** ============================================
 *  REAL-WORLD LAYOUT PATTERNS
 *  ============================================ */

export function ModalActionButtons() {
  // Typical modal footer with action buttons
  return (
    <ButtonContainer horizontal align="space-between" gap={12}>
      <SecondaryButton label="Cancel" onPress={() => {}} />
      <PrimaryButton label="Confirm" onPress={() => {}} />
    </ButtonContainer>
  );
}

export function FormActionButtons() {
  // Form submission with multiple options
  return (
    <ButtonContainer horizontal={false} align="flex-start" gap={12}>
      <PrimaryButton label="Submit Form" onPress={() => {}} />
      <SecondaryButton label="Save as Draft" onPress={() => {}} />
    </ButtonContainer>
  );
}

export function WizardNavigation() {
  // Multi-step wizard navigation
  return (
    <ButtonContainer horizontal align="space-between" gap={12}>
      <SecondaryButton label="← Previous" onPress={() => {}} />
      <SecondaryButton label="Cancel" onPress={() => {}} />
      <PrimaryButton label="Next →" onPress={() => {}} />
    </ButtonContainer>
  );
}

export function SettingsActions() {
  // Settings page with destructive action at bottom
  return (
    <ButtonContainer horizontal={false} align="flex-start" gap={12}>
      <PrimaryButton label="Save Settings" onPress={() => {}} />
      <DangerButton label="Sign Out" onPress={() => {}} filled={true} />
    </ButtonContainer>
  );
}

export function ConfirmationActions() {
  // Confirmation dialog with destructive action
  return (
    <ButtonContainer horizontal align="center" gap={12} wrap={true}>
      <SecondaryButton label="Keep" onPress={() => {}} />
      <DangerButton label="Delete Permanently" onPress={() => {}} filled={true} />
    </ButtonContainer>
  );
}

/** ============================================
 *  ALIGNMENT VARIATIONS
 *  ============================================ */

export function AlignmentExamples() {
  return (
    <>
      {/* Left-aligned (default) */}
      <PrimaryButton label="Left Aligned" onPress={() => {}} align="flex-start" />

      {/* Center-aligned */}
      <PrimaryButton label="Center Aligned" onPress={() => {}} align="center" />

      {/* Right-aligned */}
      <PrimaryButton label="Right Aligned" onPress={() => {}} align="flex-end" />

      {/* Container with different alignment */}
      <ButtonContainer horizontal align="flex-end" gap={8}>
        <SecondaryButton label="Cancel" onPress={() => {}} />
        <PrimaryButton label="Save" onPress={() => {}} />
      </ButtonContainer>
    </>
  );
}

/** ============================================
 *  SIZING CHARACTERISTICS
 *  ============================================ */

// Buttons now auto-size based on text length:
// - "OK" → Small button (~36px wide)
// - "Save Changes" → Medium button (~112px wide)
// - "Confirm Delete Permanently" → Larger button (~240px wide)

// All with consistent padding:
// - Horizontal: 16px on each side
// - Vertical: 12px on top/bottom

// Formula: button_width = text_width + (16px × 2)
// Example: "Save" (32px) + 32px padding = 64px total width

// Full-width buttons (wide={true}):
// - Stretches to 100% of parent container
// - Use sparingly (modals, full-width forms)

/** ============================================
 *  COLOR & STYLING REFERENCE
 *  ============================================ */

// PrimaryButton:
// - Background: #A855F7 (Vivid Purple)
// - Border: #9333EA (Darker Purple)
// - Text: White
// - Shadow: 14px radius, 0.28 opacity
// - Use for: Main call-to-action

// SecondaryButton:
// - Background: #A855F7 (Vivid Purple)
// - Border: #9333EA (Darker Purple)
// - Text: White
// - Shadow: 12px radius, 0.24 opacity
// - Border-width: 1.5px (more prominent)
// - Use for: Secondary actions, cancel buttons

// DangerButton (outline):
// - Background: #A855F7 (same as primary)
// - Border: #9333EA
// - Text: White
// - Use for: Destructive actions as secondary option

// DangerButton (filled):
// - Background: #DC2626 (Red)
// - Border: #DC2626
// - Text: White
// - Shadow: 12px radius, 0.22 opacity
// - Use for: Main destructive action (delete, sign out)

/** ============================================
 *  MIGRATION CHECKLIST
 *  ============================================ */

// If you have existing buttons:
// ✓ Remove any inline width styles
// ✓ Add align prop if you need positioning
// ✓ Use ButtonContainer instead of wrapping custom divs
// ✓ Change wide={false} to align="center" for centered buttons
// ✓ Test on mobile with wrap={true} in containers
// ✓ Verify button spacing looks consistent

/** ============================================
 *  COMMON MISTAKES TO AVOID
 *  ============================================ */

// ❌ DON'T: Try to force button width
// <PrimaryButton label="Save" style={{ width: '200px' }} />

// ✅ DO: Use wide prop or ButtonContainer
// <PrimaryButton label="Save" wide={true} />

// ❌ DON'T: Nest multiple ButtonContainers
// <ButtonContainer><ButtonContainer><Button /></ButtonContainer></ButtonContainer>

// ✅ DO: Flatten the structure
// <ButtonContainer><Button /><Button /><Button /></ButtonContainer>

// ❌ DON'T: Mix alignment methods
// <View style={{ alignItems: 'center' }}><PrimaryButton align="flex-start" /></View>

// ✅ DO: Let ButtonContainer handle alignment
// <ButtonContainer horizontal align="center"><PrimaryButton /></ButtonContainer>

/** ============================================
 *  BUILD & TEST
 *  ============================================ */

// Verify changes:
// $ npm run typecheck          # TypeScript check
// $ npm run web:export         # Production build
// $ npm run web:preview        # Start dev server

// Expected output:
// - TypeScript: No errors
// - Build: 695KB main bundle
// - Server: Running on port 8087
// - Buttons: Content-based sizing visible
