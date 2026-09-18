package org.sableos.design

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun SableScreen(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier = modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(
                    horizontal = SableSpacing.ScreenHorizontal,
                    vertical = SableSpacing.ScreenVertical,
                ),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
            content = content,
        )
    }
}


@Composable
fun SableScrollableScreen(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier = modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(
                    horizontal = SableSpacing.ScreenHorizontal,
                    vertical = SableSpacing.ScreenVertical,
                ),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
            content = content,
        )
    }
}

@Composable
fun SablePanel(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 0.dp,
    ) {
        Column(
            modifier = Modifier.padding(SableSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
            content = content,
        )
    }
}

@Composable
fun SableActionButton(
    text: String,
    modifier: Modifier = Modifier,
    primary: Boolean = true,
    onClick: () -> Unit,
) {
    if (primary) {
        Button(
            onClick = onClick,
            modifier = modifier.heightIn(min = SableSize.TouchTarget),
        ) {
            Text(text)
        }
    } else {
        OutlinedButton(
            onClick = onClick,
            modifier = modifier.heightIn(min = SableSize.TouchTarget),
        ) {
            Text(text)
        }
    }
}

@Composable
fun SablePageHeader(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        if (subtitle != null) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Box(
            modifier = Modifier
                .padding(top = SableSpacing.Sm)
                .width(SableSpacing.Xxxl)
                .height(SableSize.AccentBarWidth)
                .background(MaterialTheme.colorScheme.primary),
        )
    }
}

@Composable
fun SableSectionHeader(
    title: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = title,
        modifier = modifier.fillMaxWidth(),
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontWeight = FontWeight.Medium,
    )
}

@Composable
fun SableListRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    selected: Boolean = false,
    onClick: () -> Unit,
) {
    val background =
        if (selected) {
            MaterialTheme.colorScheme.surfaceVariant
        } else {
            Color.Transparent
        }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.small)
            .background(background)
            .clickable(onClick = onClick)
            .height(SableSize.ListRowHeight),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .width(SableSize.AccentBarWidth)
                .height(SableSpacing.Xxl)
                .background(
                    if (selected) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.outlineVariant
                    },
                ),
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = SableSpacing.Lg),
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
fun SableTile(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    active: Boolean = false,
    onClick: () -> Unit,
) {
    val container =
        if (active) {
            MaterialTheme.colorScheme.primary
        } else {
            MaterialTheme.colorScheme.surfaceVariant
        }
    val content =
        if (active) {
            MaterialTheme.colorScheme.onPrimary
        } else {
            MaterialTheme.colorScheme.onSurface
        }

    Surface(
        onClick = onClick,
        modifier = modifier.heightIn(min = SableSize.TouchTarget),
        shape = MaterialTheme.shapes.medium,
        color = container,
        contentColor = content,
        tonalElevation = 0.dp,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(SableSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Sm),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = content.copy(alpha = 0.82f),
                )
            }
        }
    }
}

@Composable
fun SableDivider(
    modifier: Modifier = Modifier,
) {
    HorizontalDivider(
        modifier = modifier,
        color = MaterialTheme.colorScheme.outlineVariant,
    )
}
