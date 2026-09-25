#!/usr/bin/env python3
"""Apply/verify the approved Sable Phone + Contacts UX.

Phone and Contacts keep their upstream ContactsProvider ownership. Both add a
bounded read-only preferred-phone-number cache for list subtitles, while the
existing alphabet rails continue to use upstream section indexes. No second
contact index/database is introduced. Accounts, sync, permissions and
contact-data semantics remain untouched.
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

DIALER_HEAD = "6a629762cf425002d34ecf28596813babda7d751"
CONTACTS_HEAD = "e911d48c3f433633f5a8fb1a7fd865a071a09350"

DIALER_REPO = Path("packages/apps/Dialer")
CONTACTS_REPO = Path("packages/apps/Contacts")

DIALER_LIGHT = Path(
    "java/com/android/dialer/theme/hidden/res/values/colors_dialer_light.xml"
)
DIALER_DARK = Path(
    "java/com/android/dialer/theme/hidden/res/values-night/colors_dialer_dark.xml"
)
DIALER_TOOLBAR = Path(
    "java/com/android/dialer/main/impl/toolbar/res/layout/toolbar_layout.xml"
)
DIALER_BOTTOM_NAV = Path(
    "java/com/android/dialer/main/impl/bottomnav/res/layout/bottom_nav_bar_layout.xml"
)
DIALER_DIALPAD = Path(
    "java/com/android/dialer/dialpadview/res/values/styles.xml"
)
DIALER_CONTACTS_ADAPTER = Path(
    "java/com/android/dialer/contactsfragment/ContactsAdapter.java"
)
DIALER_CONTACT_VIEW_HOLDER = Path(
    "java/com/android/dialer/contactsfragment/ContactViewHolder.java"
)
DIALER_CONTACT_ROW = Path(
    "java/com/android/dialer/contactsfragment/res/layout/contact_row.xml"
)
DIALER_CONTACTS_FRAGMENT = Path(
    "java/com/android/dialer/contactsfragment/ContactsFragment.java"
)

CONTACTS_LIGHT = Path("res/values/colors.xml")
CONTACTS_DARK = Path("res/values-night/colors.xml")
CONTACTS_TOOLBAR = Path("res/layout/people_activity_toolbar.xml")
CONTACTS_STYLES = Path("res/values/styles.xml")
CONTACTS_INDEXER_ADAPTER = Path(
    "src/com/android/contacts/list/IndexerListAdapter.java"
)
CONTACTS_DEFAULT_ADAPTER = Path(
    "src/com/android/contacts/list/DefaultContactListAdapter.java"
)
CONTACTS_BROWSE_FRAGMENT = Path(
    "src/com/android/contacts/list/DefaultContactBrowseListFragment.java"
)

DIALER_BLOCKING = Path("java/com/android/dialer/blocking/Blocking.java")
DIALER_SETTINGS = Path(
    "java/com/android/dialer/app/settings/DialerSettingsActivity.java"
)
DIALER_APP_MANIFEST = Path("java/com/android/dialer/app/AndroidManifest.xml")

DIALER_DIRT = {
    f" M {DIALER_LIGHT.as_posix()}",
    f" M {DIALER_DARK.as_posix()}",
    f" M {DIALER_TOOLBAR.as_posix()}",
    f" M {DIALER_BOTTOM_NAV.as_posix()}",
    f" M {DIALER_DIALPAD.as_posix()}",
    f" M {DIALER_CONTACTS_ADAPTER.as_posix()}",
    f" M {DIALER_CONTACT_VIEW_HOLDER.as_posix()}",
    f" M {DIALER_CONTACT_ROW.as_posix()}",
    f" M {DIALER_CONTACTS_FRAGMENT.as_posix()}",
}

CONTACTS_DIRT = {
    f" M {CONTACTS_LIGHT.as_posix()}",
    f" M {CONTACTS_DARK.as_posix()}",
    f" M {CONTACTS_TOOLBAR.as_posix()}",
    f" M {CONTACTS_STYLES.as_posix()}",
    f" M {CONTACTS_INDEXER_ADAPTER.as_posix()}",
    f" M {CONTACTS_DEFAULT_ADAPTER.as_posix()}",
    f" M {CONTACTS_BROWSE_FRAGMENT.as_posix()}",
}

CONTACTS_PARTIAL_SCOPE_MARKER = "R9_CONTACTS_PRESENTATION_PARTIAL_SCOPE="
CONTACTS_PARTIAL_CONVERGENCE_MARKER = (
    "R9_CONTACTS_PRESENTATION_PARTIAL_CONVERGENCE=PASS"
)

DIALER_TRANSFORMS: dict[Path, tuple[tuple[str, str], ...]] = {
    DIALER_LIGHT: (
        (
            '<color name="dialer_theme_color">#2A56C6</color>',
            '<color name="dialer_theme_color">#4D9CFF</color>',
        ),
        (
            '<color name="dialer_theme_color_20pct">#332A56C6</color>',
            '<color name="dialer_theme_color_20pct">#334D9CFF</color>',
        ),
        (
            '<color name="dialer_secondary_color">#F50057</color>',
            '<color name="dialer_secondary_color">#4D9CFF</color>',
        ),
        (
            '<color name="dialer_background_color">#FAFAFA</color>',
            '<color name="dialer_background_color">#F5F7F9</color>',
        ),
        (
            '<color name="settings_primary_dark">#1C3AA9</color>',
            '<color name="settings_primary_dark">#45515F</color>',
        ),
    ),
    DIALER_DARK: (
        (
            '<color name="dialer_theme_color">#5195EA</color>',
            '<color name="dialer_theme_color">#4D9CFF</color>',
        ),
        (
            '<color name="dialer_theme_color_20pct">#335195EA</color>',
            '<color name="dialer_theme_color_20pct">#334D9CFF</color>',
        ),
        (
            '<color name="dialer_secondary_color">#5195EA</color>',
            '<color name="dialer_secondary_color">#4D9CFF</color>',
        ),
        (
            '<color name="settings_primary_dark">#2374CE</color>',
            '<color name="settings_primary_dark">#45515F</color>',
        ),
    ),
    DIALER_TOOLBAR: (
        (
            'android:background="@drawable/search_bar_background_rounded_corners"',
            'android:background="@android:color/transparent"',
        ),
        (
            'android:elevation="4dp"',
            'android:elevation="0dp"',
        ),
    ),
    DIALER_BOTTOM_NAV: (
        (
            'android:elevation="8dp"',
            'android:elevation="0dp"',
        ),
    ),
    DIALER_DIALPAD: (
        (
            '<item name="android:background">@drawable/btn_dialpad_key</item>',
            '<item name="android:background">@android:color/transparent</item>',
        ),
    ),
    DIALER_CONTACTS_ADAPTER: (
        (
            '''  String getHeaderString(int position) {
    if (header != Header.NONE) {
      if (position == 0) {
        return "+";
      }
      position--;
    }

    int index = -1;
    int sum = 0;
    while (sum <= position) {
      sum += counts[++index];
    }
    return headers[index];
  }
}''',
            '''  String getHeaderString(int position) {
    if (header != Header.NONE) {
      if (position == 0) {
        return "+";
      }
      position--;
    }

    int index = -1;
    int sum = 0;
    while (sum <= position) {
      sum += counts[++index];
    }
    return headers[index];
  }

  boolean hasContacts() {
    return cursor != null && !cursor.isClosed() && cursor.getCount() > 0;
  }

  /**
   * Returns the RecyclerView position for an alphabet section using the
   * ContactsProvider address-book index already carried by this adapter.
   */
  int getPositionForHeader(String target) {
    if (headers == null || counts == null || target == null) {
      return -1;
    }

    int position = header == Header.NONE ? 0 : 1;
    for (int index = 0; index < headers.length && index < counts.length; index++) {
      String section = headers[index] == null ? "" : headers[index].trim();
      if (!section.isEmpty() && section.substring(0, 1).equalsIgnoreCase(target)) {
        return position;
      }
      position += counts[index];
    }
    return -1;
  }
}''',
        ),
        (
            '''import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
''',
            '''import android.support.v7.widget.RecyclerView;
import android.util.LongSparseArray;
import android.view.LayoutInflater;
''',
        ),
        (
            '''  // Cursor with list of contacts
  private Cursor cursor;
''',
            '''  // Cursor with list of contacts
  private Cursor cursor;
  private LongSparseArray<String> phoneNumbers = new LongSparseArray<>();
''',
        ),
        (
            '''  void updateCursor(Cursor cursor) {
    this.cursor = cursor;
    headers = cursor.getExtras().getStringArray(Contacts.EXTRA_ADDRESS_BOOK_INDEX_TITLES);
    counts = cursor.getExtras().getIntArray(Contacts.EXTRA_ADDRESS_BOOK_INDEX_COUNTS);
    if (counts != null) {
      int sum = 0;
      for (int count : counts) {
        sum += count;
      }

      if (sum != cursor.getCount()) {
        LogUtil.e(
            "ContactsAdapter", "Count sum (%d) != cursor count (%d).", sum, cursor.getCount());
      }
    }
    notifyDataSetChanged();
  }
''',
            '''  void updateCursor(Cursor cursor) {
    this.cursor = cursor;
    headers = cursor.getExtras().getStringArray(Contacts.EXTRA_ADDRESS_BOOK_INDEX_TITLES);
    counts = cursor.getExtras().getIntArray(Contacts.EXTRA_ADDRESS_BOOK_INDEX_COUNTS);
    if (counts != null) {
      int sum = 0;
      for (int count : counts) {
        sum += count;
      }

      if (sum != cursor.getCount()) {
        LogUtil.e(
            "ContactsAdapter", "Count sum (%d) != cursor count (%d).", sum, cursor.getCount());
      }
    }
    notifyDataSetChanged();
  }

  void updatePhoneNumbers(LongSparseArray<String> phoneNumbers) {
    this.phoneNumbers = phoneNumbers == null ? new LongSparseArray<>() : phoneNumbers;
    notifyDataSetChanged();
  }
''',
        ),
        (
            '''    String name = getDisplayName(cursor);
    String header = getHeaderString(position);
    Uri contactUri = getContactUri(cursor);
''',
            '''    String name = getDisplayName(cursor);
    String header = getHeaderString(position);
    long contactId = getContactId(cursor);
    String phoneNumber = phoneNumbers.get(contactId);
    Uri contactUri = getContactUri(cursor);
''',
        ),
        (
            '''    contactViewHolder.bind(header, name, contactUri, getContactId(cursor), showHeader);
''',
            '''    contactViewHolder.bind(
        header, name, phoneNumber, contactUri, contactId, showHeader);
''',
        ),
    ),
    DIALER_CONTACT_VIEW_HOLDER: (
        (
            '''  private final TextView header;
  private final BidiTextView name;
  private final QuickContactBadge photo;
''',
            '''  private final TextView header;
  private final BidiTextView name;
  private final BidiTextView phoneNumber;
  private final QuickContactBadge photo;
''',
        ),
        (
            '''    header = itemView.findViewById(R.id.header);
    name = itemView.findViewById(R.id.contact_name);
    photo = itemView.findViewById(R.id.photo);
''',
            '''    header = itemView.findViewById(R.id.header);
    name = itemView.findViewById(R.id.contact_name);
    phoneNumber = itemView.findViewById(R.id.contact_phone_number);
    photo = itemView.findViewById(R.id.photo);
''',
        ),
        (
            '''  public void bind(
      String headerText, String displayName, Uri contactUri, long contactId, boolean showHeader) {
''',
            '''  public void bind(
      String headerText,
      String displayName,
      String phoneNumberText,
      Uri contactUri,
      long contactId,
      boolean showHeader) {
''',
        ),
        (
            '''    name.setText(displayName);
    header.setText(headerText);
''',
            '''    name.setText(displayName);
    phoneNumber.setText(phoneNumberText);
    phoneNumber.setVisibility(TextUtils.isEmpty(phoneNumberText) ? View.GONE : View.VISIBLE);
    header.setText(headerText);
''',
        ),
    ),
    DIALER_CONTACT_ROW: (
        (
            '''    <com.android.dialer.widget.BidiTextView
        android:id="@+id/contact_name"
        android:layout_width="wrap_content"
        android:layout_height="match_parent"
        android:paddingStart="@dimen/text_padding_start"
        android:paddingEnd="@dimen/text_padding_end"
        android:maxLines="1"
        android:ellipsize="end"
        android:gravity="center_vertical"
        android:textSize="@dimen/text_size"
        android:textColor="?android:attr/textColorPrimary"
        android:fontFamily="sans-serif"/>
''',
            '''    <LinearLayout
        android:orientation="vertical"
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_weight="1"
        android:paddingStart="@dimen/text_padding_start"
        android:paddingEnd="@dimen/text_padding_end"
        android:gravity="center_vertical">

      <com.android.dialer.widget.BidiTextView
          android:id="@+id/contact_name"
          android:layout_width="match_parent"
          android:layout_height="wrap_content"
          android:maxLines="1"
          android:ellipsize="end"
          android:textSize="@dimen/text_size"
          android:textColor="?android:attr/textColorPrimary"
          android:fontFamily="sans-serif"/>

      <com.android.dialer.widget.BidiTextView
          android:id="@+id/contact_phone_number"
          android:layout_width="match_parent"
          android:layout_height="wrap_content"
          android:maxLines="1"
          android:ellipsize="end"
          android:textSize="14sp"
          android:textColor="?android:attr/textColorSecondary"
          android:fontFamily="sans-serif"/>
    </LinearLayout>
''',
        ),
    ),
    DIALER_CONTACTS_FRAGMENT: (
        (
            '''import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnScrollChangeListener;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
''',
            '''import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnScrollChangeListener;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
''',
        ),
        (
            '''  private FastScroller fastScroller;
  private TextView anchoredHeader;
  private RecyclerView recyclerView;
''',
            '''  private FastScroller fastScroller;
  private TextView anchoredHeader;
  private LinearLayout sableAlphabetRail;
  private RecyclerView recyclerView;
''',
        ),
        (
            '''    if (PermissionsUtil.hasContactsReadPermissions(getContext())) {
      loadContacts();
    } else {
''',
            '''    installSableAlphabetRail((FrameLayout) view);

    if (PermissionsUtil.hasContactsReadPermissions(getContext())) {
      loadContacts();
    } else {
''',
        ),
        (
            '''    return view;
  }

  @Override
  public void onResume() {
''',
            '''    return view;
  }

  private void installSableAlphabetRail(FrameLayout container) {
    sableAlphabetRail = new LinearLayout(getContext());
    sableAlphabetRail.setOrientation(LinearLayout.VERTICAL);
    sableAlphabetRail.setGravity(Gravity.CENTER);
    sableAlphabetRail.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES);

    float density = getResources().getDisplayMetrics().density;
    int width = (int) (28 * density + 0.5f);
    FrameLayout.LayoutParams params =
        new FrameLayout.LayoutParams(width, ViewGroup.LayoutParams.MATCH_PARENT, Gravity.END);
    sableAlphabetRail.setLayoutParams(params);

    for (char letter = 'A'; letter <= 'Z'; letter++) {
      final String section = String.valueOf(letter);
      TextView shortcut = new TextView(getContext());
      shortcut.setText(section);
      shortcut.setTextSize(10);
      shortcut.setGravity(Gravity.CENTER);
      shortcut.setContentDescription("Jump to " + section);
      shortcut.setFocusable(true);
      shortcut.setClickable(true);
      shortcut.setOnClickListener(
          ignored -> {
            int position = adapter == null ? -1 : adapter.getPositionForHeader(section);
            if (position >= 0) {
              manager.scrollToPositionWithOffset(position, 0);
            }
          });
      shortcut.setLayoutParams(
          new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
      sableAlphabetRail.addView(shortcut);
    }

    container.addView(sableAlphabetRail);
    updateSableAlphabetRailVisibility();
  }

  private void updateSableAlphabetRailVisibility() {
    if (sableAlphabetRail == null) {
      return;
    }
    boolean hasContacts = adapter != null && adapter.hasContacts();
    boolean searching = query != null && !query.isEmpty();
    sableAlphabetRail.setVisibility(hasContacts && !searching ? View.VISIBLE : View.GONE);
  }

  @Override
  public void onResume() {
''',
        ),
        (
            '''  public void updateQuery(String query) {
    this.query = query;
    getLoaderManager().restartLoader(0, null, this);
  }
''',
            '''  public void updateQuery(String query) {
    this.query = query;
    updateSableAlphabetRailVisibility();
    getLoaderManager().restartLoader(0, null, this);
  }
''',
        ),
        (
            '''      PerformanceReport.logOnScrollStateChange(recyclerView);
      fastScroller.setup(adapter, manager);
    }
  }
''',
            '''      PerformanceReport.logOnScrollStateChange(recyclerView);
      fastScroller.setup(adapter, manager);
      updateSableAlphabetRailVisibility();
    }
  }
''',
        ),
    ),
}

CONTACTS_TRANSFORMS: dict[Path, tuple[tuple[str, str], ...]] = {
    CONTACTS_LIGHT: (
        (
            '<color name="action_bar_background">#2a56c6</color>',
            '<color name="action_bar_background">#4D9CFF</color>',
        ),
        (
            '<color name="primary_color_dark">#1c3aa9</color>',
            '<color name="primary_color_dark">#45515F</color>',
        ),
        (
            '<color name="primary_color">#2a56c6</color>',
            '<color name="primary_color">#4D9CFF</color>',
        ),
        (
            '<color name="divider_line_color_light">#e0e0e0</color>',
            '<color name="divider_line_color_light">#D0D6DD</color>',
        ),
        (
            '<color name="background_primary">#f9f9f9</color>',
            '<color name="background_primary">#F5F7F9</color>',
        ),
        (
            '<color name="contact_all_list_background_color">#FFFFFF</color>',
            '<color name="contact_all_list_background_color">#F5F7F9</color>',
        ),
        (
            '<color name="navigation_drawer_background_color">#FAFAFA</color>',
            '<color name="navigation_drawer_background_color">#F5F7F9</color>',
        ),
    ),
    CONTACTS_DARK: (
        (
            '<color name="action_bar_background">#CC2A56C6</color>',
            '<color name="action_bar_background">#4D9CFF</color>',
        ),
        (
            '<color name="primary_color_dark">#265AB6</color>',
            '<color name="primary_color_dark">#45515F</color>',
        ),
        (
            '<color name="primary_color">#3872D7</color>',
            '<color name="primary_color">#4D9CFF</color>',
        ),
        (
            '<color name="divider_line_color_light">#525252</color>',
            '<color name="divider_line_color_light">#26313D</color>',
        ),
        (
            '<color name="background_primary">#181717</color>',
            '<color name="background_primary">#05070A</color>',
        ),
        (
            '<color name="contact_all_list_background_color">#2C2C2C</color>',
            '<color name="contact_all_list_background_color">#0D1117</color>',
        ),
        (
            '<color name="navigation_drawer_background_color">#181717</color>',
            '<color name="navigation_drawer_background_color">#05070A</color>',
        ),
    ),
    CONTACTS_TOOLBAR: (
        (
            'android:elevation="@dimen/tab_elevation"',
            'android:elevation="0dp"',
        ),
    ),
    CONTACTS_STYLES: (
        (
            '''    <style name="SectionHeaderStyle" parent="@android:style/TextAppearance.Large">
        <item name="android:textSize">16sp</item>
        <item name="android:textAllCaps">true</item>
        <item name="android:textColor">@color/section_header_text_color</item>
        <item name="android:textStyle">bold</item>
    </style>''',
            '''    <style name="SectionHeaderStyle" parent="@android:style/TextAppearance.Large">
        <item name="android:textSize">22sp</item>
        <item name="android:textAllCaps">false</item>
        <item name="android:textColor">@color/section_header_text_color</item>
        <item name="android:textStyle">normal</item>
        <item name="android:fontFamily">sans-serif-light</item>
    </style>''',
        ),
    ),
    CONTACTS_INDEXER_ADAPTER: (
        (
            '''    public int getPositionForSection(int sectionIndex) {
        if (mIndexer == null) {
            return -1;
        }

        return mIndexer.getPositionForSection(sectionIndex);
    }
''',
            '''    public int getPositionForSection(int sectionIndex) {
        if (mIndexer == null) {
            return -1;
        }

        return mIndexer.getPositionForSection(sectionIndex);
    }

    /**
     * Returns the absolute ListView position for a section. Sable's alphabet
     * rail deliberately delegates to the existing Contacts section index.
     */
    public int getListPositionForSection(int sectionIndex) {
        int offset = getPositionForSection(sectionIndex);
        if (offset < 0) {
            return -1;
        }

        int partitionStart = getPositionForPartition(mIndexedPartition);
        if (hasHeader(mIndexedPartition)) {
            partitionStart++;
        }
        return partitionStart + offset;
    }
''',
        ),
    ),
    CONTACTS_BROWSE_FRAGMENT: (
        (
            '''import android.widget.ImageView;
import android.widget.LinearLayout.LayoutParams;
''',
            '''import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.LinearLayout.LayoutParams;
''',
        ),
        (
            '''    private TextView mSearchProgressText;

    private SwipeRefreshLayout mSwipeRefreshLayout;
''',
            '''    private TextView mSearchProgressText;
    private View mSableAlphabetRail;

    private SwipeRefreshLayout mSwipeRefreshLayout;
''',
        ),
        (
            '''                private void setQueryTextToFragment(String query) {
                    setQueryString(query, true);
                    setVisibleScrollbarEnabled(!isSearchMode());
                }
''',
            '''                private void setQueryTextToFragment(String query) {
                    setQueryString(query, true);
                    setVisibleScrollbarEnabled(!isSearchMode());
                    updateSableAlphabetRailVisibility();
                }
''',
        ),
        (
            '''        super.onLoadFinished(loader, data);
        if (!isSearchMode()) {
''',
            '''        super.onLoadFinished(loader, data);
        updateSableAlphabetRailVisibility();
        if (!isSearchMode()) {
''',
        ),
        (
            '''        contactListLayout.addView(mEmptyAccountView);
        contactListLayout.addView(mEmptyHomeView);

        return view;
    }

    private View getEmptyHomeView(LayoutInflater inflater) {
''',
            '''        contactListLayout.addView(mEmptyAccountView);
        contactListLayout.addView(mEmptyHomeView);
        installSableAlphabetRail(contactListLayout);

        return view;
    }

    private void installSableAlphabetRail(FrameLayout container) {
        final LinearLayout rail = new LinearLayout(getContext());
        rail.setOrientation(LinearLayout.VERTICAL);
        rail.setGravity(Gravity.CENTER);
        rail.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES);

        final float density = getResources().getDisplayMetrics().density;
        final int width = (int) (28 * density + 0.5f);
        final FrameLayout.LayoutParams railParams =
                new FrameLayout.LayoutParams(
                        width,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        Gravity.END);
        rail.setLayoutParams(railParams);

        for (char letter = 'A'; letter <= 'Z'; letter++) {
            final String section = String.valueOf(letter);
            final TextView shortcut = new TextView(getContext());
            shortcut.setText(section);
            shortcut.setTextSize(10);
            shortcut.setGravity(Gravity.CENTER);
            shortcut.setTextColor(
                    ContextCompat.getColor(getContext(), R.color.primary_color));
            shortcut.setContentDescription("Jump to " + section);
            shortcut.setFocusable(true);
            shortcut.setClickable(true);
            shortcut.setOnClickListener(v -> scrollToSableSection(section));
            shortcut.setLayoutParams(
                    new LinearLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            0,
                            1f));
            rail.addView(shortcut);
        }

        mSableAlphabetRail = rail;
        container.addView(rail);
        updateSableAlphabetRailVisibility();
    }

    private void updateSableAlphabetRailVisibility() {
        if (mSableAlphabetRail != null) {
            mSableAlphabetRail.setVisibility(isSearchMode() ? View.GONE : View.VISIBLE);
        }
    }

    private void scrollToSableSection(String target) {
        final ContactListAdapter adapter = getAdapter();
        if (adapter == null) {
            return;
        }

        final Object[] sections = adapter.getSections();
        for (int index = 0; index < sections.length; index++) {
            final String section = String.valueOf(sections[index]).trim();
            if (section.isEmpty()) {
                continue;
            }
            if (section.substring(0, 1).equalsIgnoreCase(target)) {
                final int position = adapter.getListPositionForSection(index);
                if (position >= 0) {
                    getListView().setSelection(position);
                }
                return;
            }
        }
    }

    private View getEmptyHomeView(LayoutInflater inflater) {
''',
        ),
    ),
}


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=True,
        stderr=subprocess.STDOUT,
    ).rstrip("\n")


def status(repo: Path) -> set[str]:
    out = git(repo, "status", "--porcelain", "--untracked-files=all")
    return {line for line in out.splitlines() if line}


def head_text(repo: Path, rel: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), "show", f"HEAD:{rel.as_posix()}"],
        text=True,
        stderr=subprocess.STDOUT,
    )


def classify_text_state(
    actual: str,
    pinned: str,
    canonical: str,
    label: str,
) -> str:
    if actual == pinned:
        return "PINNED"
    if actual == canonical:
        return "CANONICAL"
    raise SystemExit(
        f"R9_{label}_CONTENT_STATE=FAIL "
        "expected=PINNED_OR_CANONICAL"
    )


def assert_head(source: Path, repo: Path, expected: str) -> None:
    actual = git(source / repo, "rev-parse", "HEAD")
    if actual != expected:
        raise SystemExit(
            f"R9_PHONE_CONTACTS_HEAD=FAIL repo={repo} "
            f"expected={expected} actual={actual}"
        )


def replacement_state(text: str, old: str, new: str) -> tuple[int, int]:
    new_count = text.count(new)
    residual = text.replace(new, "", new_count)
    old_outside_new_count = residual.count(old)
    return new_count, old_outside_new_count


def transform_text(
    text: str,
    replacements: tuple[tuple[str, str], ...],
    label: str,
) -> str:
    for old, new in replacements:
        new_count, old_outside_new_count = replacement_state(text, old, new)

        if new_count == 1 and old_outside_new_count == 0:
            continue

        if new_count != 0 or old_outside_new_count != 1:
            raise SystemExit(
                f"R9_PHONE_CONTACTS_TRANSFORM=FAIL file={label} "
                f"new_count={new_count} "
                f"old_outside_new_count={old_outside_new_count} "
                f"old={old!r}"
            )

        text = text.replace(old, new, 1)
    return text


def inspect_repo_state(
    root: Path,
    transforms: dict[Path, tuple[tuple[str, str], ...]],
    expected_dirt: set[str],
    label: str,
) -> tuple[set[str], dict[Path, tuple[str, str]]]:
    current = status(root)
    unexpected = current - expected_dirt
    if unexpected:
        raise SystemExit(
            f"R9_{label}_DIRTY_SCOPE_UNEXPECTED=FAIL "
            f"paths={sorted(unexpected)!r}"
        )

    states: dict[Path, tuple[str, str]] = {}
    for rel, replacements in transforms.items():
        pinned = head_text(root, rel)
        canonical = transform_text(pinned, replacements, rel.as_posix())
        actual = (root / rel).read_text(encoding="utf-8")
        state = classify_text_state(
            actual,
            pinned,
            canonical,
            label,
        )
        marker = f" M {rel.as_posix()}"
        if state == "PINNED" and marker in current:
            raise SystemExit(
                f"R9_{label}_STATUS_CONTENT_MISMATCH=FAIL "
                f"file={rel} state=PINNED status=DIRTY"
            )
        if state == "CANONICAL" and marker not in current:
            raise SystemExit(
                f"R9_{label}_STATUS_CONTENT_MISMATCH=FAIL "
                f"file={rel} state=CANONICAL status=CLEAN"
            )
        states[rel] = (state, canonical)

    return current, states


def apply_repo(
    root: Path,
    transforms: dict[Path, tuple[tuple[str, str], ...]],
    expected_dirt: set[str],
    label: str,
) -> None:
    current, states = inspect_repo_state(
        root,
        transforms,
        expected_dirt,
        label,
    )
    if current == expected_dirt:
        print(f"R9_{label}_PRESENTATION=ALREADY_APPLIED")
        return

    if current:
        if label == "CONTACTS":
            print(f"{CONTACTS_PARTIAL_SCOPE_MARKER}{sorted(current)!r}")
        else:
            print(
                f"R9_{label}_PRESENTATION_PARTIAL_SCOPE="
                f"{sorted(current)!r}"
            )

    for rel, (state, canonical) in states.items():
        if state == "PINNED":
            (root / rel).write_text(canonical, encoding="utf-8")

    final, final_states = inspect_repo_state(
        root,
        transforms,
        expected_dirt,
        label,
    )
    if final != expected_dirt:
        raise SystemExit(
            f"R9_{label}_DIRTY_SCOPE=FAIL "
            f"expected={sorted(expected_dirt)!r} actual={sorted(final)!r}"
        )
    if any(state != "CANONICAL" for state, _ in final_states.values()):
        raise SystemExit(f"R9_{label}_CANONICAL_CONVERGENCE=FAIL")

    if current:
        if label == "CONTACTS":
            print(CONTACTS_PARTIAL_CONVERGENCE_MARKER)
        else:
            print(f"R9_{label}_PRESENTATION_PARTIAL_CONVERGENCE=PASS")
    print(f"R9_{label}_PRESENTATION=APPLIED")

def verify_repo(
    root: Path,
    transforms: dict[Path, tuple[tuple[str, str], ...]],
    expected_dirt: set[str],
    label: str,
) -> None:
    current, states = inspect_repo_state(
        root,
        transforms,
        expected_dirt,
        label,
    )
    if current != expected_dirt:
        raise SystemExit(
            f"R9_{label}_VERIFY_DIRTY_SCOPE=FAIL "
            f"expected={sorted(expected_dirt)!r} actual={sorted(current)!r}"
        )
    if any(state != "CANONICAL" for state, _ in states.values()):
        raise SystemExit(f"R9_{label}_VERIFY_CANONICAL_STATE=FAIL")

    for rel, replacements in transforms.items():
        text = (root / rel).read_text(encoding="utf-8")
        for old, new in replacements:
            new_count, old_outside_new_count = replacement_state(
                text,
                old,
                new,
            )
            if new_count != 1 or old_outside_new_count != 0:
                raise SystemExit(
                    f"R9_{label}_VERIFY=FAIL file={rel} "
                    f"new_count={new_count} "
                    f"old_outside_new_count={old_outside_new_count} "
                    f"old={old!r}"
                )

    behavioral = {
        line for line in current
        if line[3:].endswith((".java", ".kt"))
    }
    if label == "PHONE":
        allowed_behavioral = {
            f" M {DIALER_CONTACTS_ADAPTER.as_posix()}",
            f" M {DIALER_CONTACTS_FRAGMENT.as_posix()}",
        }
        if behavioral != allowed_behavioral:
            raise SystemExit(
                "R9_PHONE_BEHAVIORAL_SCOPE=FAIL "
                f"expected={sorted(allowed_behavioral)!r} actual={sorted(behavioral)!r}"
            )
        print("R9_PHONE_BEHAVIORAL_SCOPE=PASS_CONTACTS_ALPHABET_RAIL_ONLY")
    else:
        allowed_behavioral = {
            f" M {CONTACTS_INDEXER_ADAPTER.as_posix()}",
            f" M {CONTACTS_BROWSE_FRAGMENT.as_posix()}",
        }
        if behavioral != allowed_behavioral:
            raise SystemExit(
                "R9_CONTACTS_BEHAVIORAL_SCOPE=FAIL "
                f"expected={sorted(allowed_behavioral)!r} actual={sorted(behavioral)!r}"
            )
        print("R9_CONTACTS_BEHAVIORAL_SCOPE=PASS_ALPHABET_RAIL_ONLY")

    print(f"R9_{label}_PRESENTATION=PASS")


def apply(source: Path) -> None:
    assert_head(source, DIALER_REPO, DIALER_HEAD)
    assert_head(source, CONTACTS_REPO, CONTACTS_HEAD)

    apply_repo(
        source / DIALER_REPO,
        DIALER_TRANSFORMS,
        DIALER_DIRT,
        "PHONE",
    )
    apply_repo(
        source / CONTACTS_REPO,
        CONTACTS_TRANSFORMS,
        CONTACTS_DIRT,
        "CONTACTS",
    )
    verify(source)


def verify_blocking_substrate(source: Path) -> None:
    dialer = source / DIALER_REPO

    blocking = (dialer / DIALER_BLOCKING).read_text(encoding="utf-8")
    for needle in (
        "android.provider.BlockedNumberContract",
        "BlockedNumbers.COLUMN_ORIGINAL_NUMBER",
        "BlockedNumbers.COLUMN_E164_NUMBER",
        "ContentProviderOperation.newInsert(BlockedNumbers.CONTENT_URI)",
        "ContentProviderOperation.newDelete(BlockedNumbers.CONTENT_URI)",
        "resolver.applyBatch(BlockedNumberContract.AUTHORITY, ops)",
    ):
        if needle not in blocking:
            raise SystemExit(
                "R9_BLOCKED_NUMBER_PLATFORM_SUBSTRATE=FAIL "
                f"file={DIALER_BLOCKING} missing={needle!r}"
            )

    settings = (dialer / DIALER_SETTINGS).read_text(encoding="utf-8")
    for needle in (
        "FilteredNumberCompat.canCurrentUserOpenBlockSettings(this)",
        "R.string.manage_blocked_numbers_label",
        "FilteredNumberCompat.createManageBlockedNumbersIntent(this)",
    ):
        if needle not in settings:
            raise SystemExit(
                "R9_BLOCKED_NUMBER_SETTINGS_UI=FAIL "
                f"file={DIALER_SETTINGS} missing={needle!r}"
            )

    manifest = (dialer / DIALER_APP_MANIFEST).read_text(encoding="utf-8")
    for needle in (
        "com.android.dialer.app.filterednumber.BlockedNumbersSettingsActivity",
        "com.android.dialer.action.BLOCKED_NUMBERS_SETTINGS",
        'android:exported="false"',
    ):
        if needle not in manifest:
            raise SystemExit(
                "R9_BLOCKED_NUMBER_SETTINGS_ACTIVITY=FAIL "
                f"file={DIALER_APP_MANIFEST} missing={needle!r}"
            )

    print("R9_BLOCKED_NUMBER_PLATFORM_SUBSTRATE=PASS")
    print("R9_BLOCKED_NUMBER_SETTINGS_UI=PASS")
    print("R9_SMS_MMS_BLOCKING_OWNER=ANDROID_BLOCKED_NUMBER_PROVIDER")
    print("R9_SMS_MMS_BLOCKING_MESSAGING_FORK_REQUIRED=NO")


def verify(source: Path) -> None:
    assert_head(source, DIALER_REPO, DIALER_HEAD)
    assert_head(source, CONTACTS_REPO, CONTACTS_HEAD)
    verify_blocking_substrate(source)

    verify_repo(
        source / DIALER_REPO,
        DIALER_TRANSFORMS,
        DIALER_DIRT,
        "PHONE",
    )
    verify_repo(
        source / CONTACTS_REPO,
        CONTACTS_TRANSFORMS,
        CONTACTS_DIRT,
        "CONTACTS",
    )

    print("R9_PHONE_CONTACTS_PINNED_BASELINES=PASS")
    print("R9_PHONE_CONTACTS_PRESENTATION=PASS")
    print("R9_PHONE_CONTACTS_ALPHABET_RAIL=PASS_EXISTING_ADDRESS_BOOK_INDEX")
    print("R9_CONTACTS_ALPHABET_RAIL=PASS_EXISTING_SECTION_INDEXER")
    print("R9_CONTACTS_DATA_MODEL_MUTATION=NONE")


def self_test() -> None:
    for label, transforms in (
        ("PHONE", DIALER_TRANSFORMS),
        ("CONTACTS", CONTACTS_TRANSFORMS),
    ):
        for path, replacements in transforms.items():
            fixture = "\n".join(old for old, _ in replacements)
            updated = transform_text(fixture, replacements, path.as_posix())
            for old, new in replacements:
                new_count, old_outside_new_count = replacement_state(
                    updated,
                    old,
                    new,
                )
                if new_count != 1 or old_outside_new_count != 0:
                    raise SystemExit(
                        f"R9_{label}_SELF_TEST=FAIL file={path} "
                        f"new_count={new_count} "
                        f"old_outside_new_count={old_outside_new_count}"
                    )

            repeated = transform_text(updated, replacements, path.as_posix())
            if repeated != updated:
                raise SystemExit(
                    f"R9_{label}_SELF_TEST=FAIL_IDEMPOTENCE file={path}"
                )

    nested_old = """    public int getPositionForSection(int sectionIndex) {
        if (mIndexer == null) {
            return -1;
        }

        return mIndexer.getPositionForSection(sectionIndex);
    }
"""
    nested_new = nested_old + """
    public int getListPositionForSection(int sectionIndex) {
        return sectionIndex;
    }
"""
    new_count, old_outside_new_count = replacement_state(
        nested_new,
        nested_old,
        nested_new,
    )
    if new_count != 1 or old_outside_new_count != 0:
        raise SystemExit(
            "R9_PHONE_CONTACTS_SELF_TEST=FAIL_NESTED_REPLACEMENT_STATE"
        )
    print("R9_PHONE_CONTACTS_CONTAINMENT_AWARE_VERIFY_SELF_TEST=PASS")

    if classify_text_state(
        "pinned",
        "pinned",
        "canonical",
        "SELF_TEST",
    ) != "PINNED":
        raise SystemExit("R9_PHONE_CONTACTS_SELF_TEST=FAIL_PINNED_STATE")
    if classify_text_state(
        "canonical",
        "pinned",
        "canonical",
        "SELF_TEST",
    ) != "CANONICAL":
        raise SystemExit("R9_PHONE_CONTACTS_SELF_TEST=FAIL_CANONICAL_STATE")
    try:
        classify_text_state(
            "unexpected",
            "pinned",
            "canonical",
            "SELF_TEST",
        )
    except SystemExit:
        pass
    else:
        raise SystemExit(
            "R9_PHONE_CONTACTS_SELF_TEST=FAIL_CONTENT_DRIFT_REJECTION"
        )
    print("R9_PHONE_CONTACTS_PARTIAL_CONVERGENCE_SELF_TEST=PASS")

    required_blocking_tokens = (
        "BlockedNumberContract",
        "BlockedNumbers.COLUMN_ORIGINAL_NUMBER",
        "BlockedNumbers.COLUMN_E164_NUMBER",
        "canCurrentUserOpenBlockSettings",
        "createManageBlockedNumbersIntent",
        "BlockedNumbersSettingsActivity",
    )
    source_text = Path(__file__).read_text(encoding="utf-8")
    for token in required_blocking_tokens:
        if token not in source_text:
            raise SystemExit(
                f"R9_PHONE_CONTACTS_SELF_TEST=FAIL_BLOCKING_CONTRACT token={token!r}"
            )

    print("R9_BLOCKED_NUMBER_CONTRACT=PASS_SELF_TEST")
    print("R9_PHONE_CONTACTS_PINNED_BASELINES=PASS_SELF_TEST")
    print("R9_PHONE_PRESENTATION=PASS_SELF_TEST")
    print("R9_CONTACTS_PRESENTATION=PASS_SELF_TEST")
    print("R9_CONTACTS_ALPHABET_RAIL=PASS_SELF_TEST")
    print("R9_PHONE_CONTACTS_ALPHABET_RAIL=PASS_SELF_TEST")
    print("R9_PHONE_BEHAVIORAL_SCOPE=PASS_CONTACTS_ALPHABET_RAIL_ONLY_SELF_TEST")
    print("R9_PHONE_CONTACTS_PRESENTATION_SELF_TEST=PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("command", nargs="?", choices=("apply", "verify"))
    args = parser.parse_args()

    if args.self_test:
        if args.source is not None or args.command is not None:
            parser.error("--self-test cannot be combined with source/command")
        self_test()
        return 0

    if args.source is None or args.command is None:
        parser.error("--source and command are required")

    source = args.source.resolve()
    if args.command == "apply":
        apply(source)
    else:
        verify(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
