/* Synthetic APK library whose dependencies live only on vendor, or nowhere. */
extern int vendor_only(void);
extern int gone_function(void);

__attribute__((visibility("default"))) int vend_entry(void) { return vendor_only() + gone_function(); }
