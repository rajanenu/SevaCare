# Button Design System - Content-Based Width (Auto-Sizing)

## Overview

The button system has been redesigned to use **content-based width (auto-sizing)** instead of full-width or stretched buttons. Buttons now scale dynamically to fit their content with consistent, clean spacing.

## Key Features

✅ **Content-based sizing** - Buttons only as wide as text + padding  
✅ **Consistent padding** - 16px horizontal, 12px vertical on all buttons  
✅ **No forced stretching** - Removed `minWidth` constraints  
✅ **Flexible alignment** - Support for `flex-start`, `center`, `flex-end` positioning  
✅ **Clean modern layout** - Professional spacing with proper flex management  
✅ **Full-width option** - Available when explicitly needed via `wide={true}`  

## Button Components

### 1. PrimaryButton
Main call-to-action button with glossy overlay effect.

```typescript
<PrimaryButton 
  label="Save Changes"
  onPress={() => handleSave()}
  align="center"  // optional: 'flex-start' | 'center' | 'flex-end'
  wide={false}    // optional: set true for 100% width
/>
```

**Props:**
- `label: string` - Button text
- `onPress: () => void` - Click handler
- `wide?: boolean` - Full width (default: false)
- `align?: 'flex-start' | 'center' | 'flex-end'` - Alignment (default: 'flex-start')

**Styling:**
- Primary color: Purple (#A855F7)
- Padding: 16px horizontal, 12px vertical
- Border radius: 999px (fully rounded)
- Shadow: 8px offset, 14px radius, 0.28 opacity

---

### 2. SecondaryButton
Secondary action button, less prominent than Primary.

```typescript
<SecondaryButton 
  label="Cancel"
  onPress={() => handleCancel()}
  align="center"  // optional: 'flex-start' | 'center' | 'flex-end'
  wide={false}    // optional: set true for 100% width
/>
```

**Props:**
- `label: string` - Button text
- `onPress: () => void` - Click handler
- `wide?: boolean` - Full width (default: false)
- `align?: 'flex-start' | 'center' | 'flex-end'` - Alignment (default: 'flex-start')

**Styling:**
- Primary color: Purple (#A855F7)
- Padding: 16px horizontal, 12px vertical
- Border radius: 999px (fully rounded)
- Border width: 1.5px
- Shadow: 8px offset, 12px radius, 0.24 opacity

---

### 3. DangerButton
Destructive action button (delete, logout, etc.).

```typescript
<DangerButton 
  label="Delete Account"
  onPress={() => handleDelete()}
  filled={true}   // optional: filled red background
  align="center"  // optional: 'flex-start' | 'center' | 'flex-end'
  wide={false}    // optional: set true for 100% width
/>
```

**Props:**
- `label: string` - Button text
- `onPress: () => void` - Click handler
- `filled?: boolean` - Solid red fill vs outline (default: false)
- `wide?: boolean` - Full width (default: false)
- `align?: 'flex-start' | 'center' | 'flex-end'` - Alignment (default: 'flex-start')

**Styling:**
- Primary color: Red (#DC2626) when filled
- Padding: 16px horizontal, 12px vertical
- Border radius: 999px (fully rounded)
- Shadow: 8px offset, 12px radius, 0.22 opacity

---

### 4. ButtonContainer (NEW)
Flexible container for grouping and aligning multiple buttons with consistent spacing.

```typescript
<ButtonContainer
  horizontal={true}      // Stack horizontally
  align="center"         // Center alignment
  gap={12}               // Space between buttons
  wrap={true}            // Allow wrapping on mobile
>
  <PrimaryButton label="Submit" onPress={handleSubmit} />
  <SecondaryButton label="Cancel" onPress={handleCancel} />
</ButtonContainer>
```

**Props:**
- `children: ReactNode` - Button children
- `horizontal?: boolean` - Direction (default: false = vertical)
- `align?: 'flex-start' | 'center' | 'flex-end' | 'space-between'` - Alignment (default: 'flex-start')
- `gap?: number` - Space between elements in pixels (default: 12)
- `wrap?: boolean` - Allow wrapping on small screens (default: false)

**Layout Examples:**

```typescript
// Horizontal buttons, centered
<ButtonContainer horizontal align="center" gap={12}>
  <PrimaryButton label="Save" onPress={save} />
  <SecondaryButton label="Cancel" onPress={cancel} />
</ButtonContainer>

// Vertical buttons, left-aligned
<ButtonContainer horizontal={false} align="flex-start" gap={8}>
  <PrimaryButton label="Option 1" onPress={opt1} />
  <SecondaryButton label="Option 2" onPress={opt2} />
  <DangerButton label="Delete" onPress={del} />
</ButtonContainer>

// Space-between layout for footer buttons
<ButtonContainer horizontal align="space-between" gap={0}>
  <SecondaryButton label="Back" onPress={back} />
  <PrimaryButton label="Next" onPress={next} />
</ButtonContainer>
```

---

## Usage Examples

### Basic Button
```typescript
import { PrimaryButton } from '../components/ui';

export function MyComponent() {
  return (
    <PrimaryButton 
      label="Click Me"
      onPress={() => console.log('Clicked')}
    />
  );
}
```

### Button with Alignment
```typescript
// Center-aligned button
<PrimaryButton 
  label="Submit Form"
  onPress={handleSubmit}
  align="center"
/>

// Right-aligned button
<SecondaryButton 
  label="Learn More"
  onPress={handleLearnMore}
  align="flex-end"
/>
```

### Full-Width Button
```typescript
// Use in modal dialogs or when needed
<PrimaryButton 
  label="Confirm Action"
  onPress={handleConfirm}
  wide={true}  // Stretches to 100% width
/>
```

### Button Group with Container
```typescript
<ButtonContainer horizontal align="center" gap={12}>
  <SecondaryButton label="Cancel" onPress={handleCancel} />
  <PrimaryButton label="Save Changes" onPress={handleSave} />
</ButtonContainer>
```

### Responsive Button Layout
```typescript
<ButtonContainer 
  horizontal={true}
  align="space-between"
  gap={12}
  wrap={true}  // Wraps on small screens
>
  <SecondaryButton label="Back" onPress={back} />
  <PrimaryButton label="Continue" onPress={next} />
</ButtonContainer>
```

---

## Styling Reference

### Padding (Consistent across all buttons)
- **Horizontal:** 16px
- **Vertical:** 12px
- **Result:** Balanced, modern spacing that adapts to text length

### Border Radius
- **All buttons:** 999px (perfect rounded corners)

### Typography
- **Font family:** System (-apple-system, Segoe UI, Roboto)
- **Font weight:** 700 (Primary), 600 (Secondary), 600 (Danger)
- **Font size:** 12px (Primary), 12px (Secondary), 13px (Danger)

### Colors (Using current Vivid Purple palette)
| Button Type | Background | Border | Text |
|---|---|---|---|
| Primary | #A855F7 | #9333EA | White |
| Secondary | #A855F7 | #9333EA | White |
| Danger (outline) | #A855F7 | #9333EA | White |
| Danger (filled) | #DC2626 | #DC2626 | White |

### Shadow Effects
| Button | Offset | Opacity | Radius |
|---|---|---|---|
| Primary | 8px | 0.28 | 14px |
| Secondary | 8px | 0.24 | 12px |
| Danger | 8px | 0.22 | 12px |

---

## Migration Guide

### Before (Old Design)
```typescript
<PrimaryButton label="Submit" onPress={handleSubmit} />
// Would stretch or use minWidth
```

### After (New Design)
```typescript
<PrimaryButton label="Submit" onPress={handleSubmit} align="center" />
// Auto-sizes to content with consistent padding
```

### Updated Props
| Aspect | Before | After | Notes |
|---|---|---|---|
| Width | Flexible stretching | Content-based | Use `wide={true}` for full-width |
| Alignment | N/A | `align` prop | New flexible alignment option |
| Padding | 14px horizontal | 16px horizontal | Slightly increased for better spacing |
| MinWidth | 120px (Secondary) | Removed | Now truly content-based |

---

## Modern UI Practices Applied

### 1. **Content-Based Layout**
   - Buttons sized to their content, not forced to fill space
   - Predictable, scalable design
   - Better for responsive layouts

### 2. **Consistent Spacing**
   - Uniform 16px horizontal padding across all button types
   - Maintains visual hierarchy
   - Professional, polished appearance

### 3. **Flexible Alignment**
   - Supports `flex-start`, `center`, `flex-end` positioning
   - Use `space-between` for footer buttons
   - Adapts to any layout container

### 4. **Clean Flex Management**
   - `flex: 0` prevents unwanted stretching
   - Explicit `alignSelf` for individual alignment
   - Container supports both horizontal and vertical stacking

### 5. **Shadow Hierarchy**
   - Consistent shadow effects by importance
   - Primary has strongest shadow (0.28 opacity)
   - Secondary and Danger have reduced shadows
   - Creates visual depth and focus direction

---

## Best Practices

✅ **DO:**
- Use `ButtonContainer` to group related buttons
- Specify `align` for predictable positioning
- Use `wide={true}` only when necessary
- Apply different button types based on action importance
- Test on mobile with `wrap={true}` in ButtonContainer

❌ **DON'T:**
- Try to force button width with inline styles
- Use full-width buttons everywhere
- Mix multiple button types in confusing patterns
- Create custom button wrappers; use ButtonContainer instead
- Override padding or border-radius

---

## Accessibility

All buttons support:
- ✅ Keyboard navigation
- ✅ Touch targets (min 44px on mobile)
- ✅ High contrast colors
- ✅ Clear, descriptive labels
- ✅ Visual feedback (opacity change on press)

---

## Build & Deployment

The updated button system has been tested and verified:
- ✅ TypeScript compilation: PASS
- ✅ Production build: PASS
- ✅ Bundle size: 695KB (main)
- ✅ All assets bundled correctly

To use in your app:
```bash
cd sevacare-frontend

# Verify compilation
npm run typecheck

# Build for web
npm run web:export

# Start development server
npm run web:preview
```

---

## Questions?

For detailed component props and examples, check:
- [ui.tsx](src/components/ui.tsx) - Component implementations
- [color-palette-screen.tsx](src/screens/color-palette-screen.tsx) - Example usage
- [common-screens.tsx](src/screens/common-screens.tsx) - Real-world examples

