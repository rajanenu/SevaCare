# Quick Start - Button Design System

## 🎯 What Changed

Your buttons now use **content-based width (auto-sizing)** instead of fixed or stretched widths:

| Feature | Before | After |
|---------|--------|-------|
| **Width** | Flexible/stretching | Auto-sized to text + 16px padding |
| **Padding** | Mixed (14px, 10px) | Consistent 16px horizontal, 12px vertical |
| **Sizing** | Sometimes forced to 120px min-width | Truly content-based, no minimums |
| **Alignment** | Not controllable | Flexible: left, center, right, space-between |
| **Grouping** | Manual wrapping | New `ButtonContainer` component |

---

## 💡 Basic Usage

### Single Button (Auto-Sized)
```tsx
<PrimaryButton label="Save" onPress={handleSave} />
```
✅ Button is only as wide as "Save" + padding

### Button with Alignment
```tsx
<PrimaryButton label="Save" onPress={handleSave} align="center" />
```
✅ Button centered horizontally

### Full-Width Button (When Needed)
```tsx
<PrimaryButton label="Continue" onPress={next} wide={true} />
```
✅ Stretches to 100% width

### Button Group
```tsx
<ButtonContainer horizontal align="center" gap={12}>
  <SecondaryButton label="Cancel" onPress={cancel} />
  <PrimaryButton label="Save" onPress={save} />
</ButtonContainer>
```
✅ Two buttons side-by-side with 12px spacing

---

## 📦 Components

### PrimaryButton
Main call-to-action button with glossy effect
```tsx
<PrimaryButton 
  label="string"
  onPress={() => void}
  align?: 'flex-start' | 'center' | 'flex-end'
  wide?: boolean
/>
```

### SecondaryButton  
Secondary action button
```tsx
<SecondaryButton 
  label="string"
  onPress={() => void}
  align?: 'flex-start' | 'center' | 'flex-end'
  wide?: boolean
/>
```

### DangerButton
Destructive action button
```tsx
<DangerButton 
  label="string"
  onPress={() => void}
  filled?: boolean
  align?: 'flex-start' | 'center' | 'flex-end'
  wide?: boolean
/>
```

### ButtonContainer (NEW)
Flexible button grouping container
```tsx
<ButtonContainer
  horizontal?: boolean         // Stack direction
  align?: 'flex-start' | 'center' | 'flex-end' | 'space-between'
  gap?: number                 // Spacing in pixels
  wrap?: boolean               // Allow wrapping on mobile
>
  {children}
</ButtonContainer>
```

---

## 🎨 Alignment Options

```tsx
// Left-aligned (default)
<PrimaryButton label="Go" align="flex-start" />

// Center-aligned
<PrimaryButton label="Go" align="center" />

// Right-aligned
<PrimaryButton label="Go" align="flex-end" />

// In containers - space between (footer style)
<ButtonContainer horizontal align="space-between">
  <SecondaryButton label="←" onPress={back} />
  <PrimaryButton label="→" onPress={next} />
</ButtonContainer>
```

---

## 📐 Button Sizing

Buttons automatically size based on text:

**Small:** "OK" or "Yes"  
→ ~40px wide (text + 2×16px padding)

**Medium:** "Save" or "Cancel"  
→ ~90px wide

**Large:** "Save & Continue"  
→ ~170px wide

**All with consistent padding:**
- Horizontal: 16px each side
- Vertical: 12px top/bottom

---

## 🔧 Common Layouts

### Modal Footer
```tsx
<ButtonContainer horizontal align="space-between">
  <SecondaryButton label="Cancel" onPress={cancel} />
  <PrimaryButton label="Confirm" onPress={confirm} />
</ButtonContainer>
```

### Form Actions (Vertical)
```tsx
<ButtonContainer align="flex-start" gap={12}>
  <PrimaryButton label="Submit" onPress={submit} />
  <SecondaryButton label="Save Draft" onPress={draft} />
</ButtonContainer>
```

### Wizard Navigation  
```tsx
<ButtonContainer horizontal align="space-between">
  <SecondaryButton label="← Back" onPress={back} />
  <SecondaryButton label="Cancel" onPress={cancel} />
  <PrimaryButton label="Next →" onPress={next} />
</ButtonContainer>
```

### Responsive Buttons
```tsx
<ButtonContainer 
  horizontal={true}
  align="center"
  gap={12}
  wrap={true}  // Wraps on mobile
>
  <PrimaryButton label="Save" onPress={save} />
  <SecondaryButton label="Draft" onPress={draft} />
</ButtonContainer>
```

---

## 🎯 Best Practices

✅ **DO:**
- Use `ButtonContainer` for multiple buttons
- Specify `align` prop for consistent positioning
- Use `wrap={true}` in containers for mobile
- Remember: buttons auto-size to content

❌ **DON'T:**
- Try to set button width with inline styles
- Use `wide={true}` everywhere
- Force minWidth or maxWidth on buttons
- Create custom button wrappers

---

## 📚 Full Documentation

- **Complete Guide:** See `BUTTON_DESIGN.md`
- **Code Examples:** See `BUTTON_EXAMPLES.ts`
- **Source Code:** See `src/components/ui.tsx`

---

## ✨ Current Button Colors (Vivid Purple Palette)

All buttons use the consistent Vivid Purple color scheme:
- **Primary Color:** #A855F7 (Vivid Purple)
- **Dark Accent:** #9333EA (Darker Purple)
- **Danger:** #DC2626 (Red, filled style only)

---

## 🚀 Live Server

Your frontend is live at:  
**http://localhost:8087**

View the buttons in action:
1. Open the app in your browser
2. Navigate through different screens
3. All buttons auto-size based on their text
4. Check Settings → Appearance to see button color options

---

## 📋 What Was Built

- ✅ All buttons redesigned for content-based width
- ✅ Consistent padding across all button types (16px × 12px)
- ✅ New alignment control with `align` prop
- ✅ New `ButtonContainer` for button groups
- ✅ Responsive support with wrapping
- ✅ Full-width option when needed (`wide={true}`)
- ✅ TypeScript: All types correct ✅
- ✅ Production Build: Ready to deploy ✅
- ✅ Web Server: Running at http://localhost:8087 ✅

---

## 🎓 Example Transformation

**Before (Old Design):**
```tsx
// SecondaryButton was forced to minWidth: 120px
<SecondaryButton label="OK" />  // Unnecessarily wide
```

**After (New Design):**
```tsx
// Button sizes naturally to content
<SecondaryButton label="OK" align="center" />  // Perfect fit
```

---

**Ready to use!** All button changes are production-ready.  
For questions, check the documentation files listed above.

