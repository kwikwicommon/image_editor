import 'sticker_asset.dart';

class BuiltInStickerLibrary {
  static const List<StickerAsset> arrows = [
    StickerAsset(
      id: 'arrow_right',
      name: 'Right Arrow',
      category: StickerCategory.arrows,
      tags: ['arrow', 'right', 'direction'],
      svgContent:
          '<svg viewBox="0 0 100 60"><path d="M10 30 L70 30 L55 15 M70 30 L55 45" stroke="currentColor" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'arrow_curved_right',
      name: 'Curved Arrow',
      category: StickerCategory.arrows,
      tags: ['arrow', 'curved', 'bend'],
      svgContent:
          '<svg viewBox="0 0 100 80"><path d="M15 60 C15 20 85 20 85 40" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M75 30 L85 40 L75 50" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'arrow_u_turn',
      name: 'U-Turn Arrow',
      category: StickerCategory.arrows,
      tags: ['arrow', 'u-turn', 'return'],
      svgContent:
          '<svg viewBox="0 0 80 100"><path d="M20 80 L20 30 C20 15 60 15 60 30 L60 50" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M50 40 L60 50 L70 40" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'arrow_double',
      name: 'Double Arrow',
      category: StickerCategory.arrows,
      tags: ['arrow', 'double', 'both'],
      svgContent:
          '<svg viewBox="0 0 120 60"><path d="M25 30 L95 30" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M35 20 L25 30 L35 40" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="M85 20 L95 30 L85 40" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'arrow_hand_point',
      name: 'Hand Pointer',
      category: StickerCategory.arrows,
      tags: ['hand', 'point', 'finger'],
      svgContent:
          '<svg viewBox="0 0 80 80"><path d="M40 70 L40 35 M40 35 C40 25 55 25 55 35 L55 40 M55 35 C55 25 70 25 70 35 L70 50 C70 65 55 70 40 70 M40 35 C40 25 25 25 25 35 L25 50 C25 60 30 65 40 70" stroke="currentColor" stroke-width="3" fill="none" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'arrow_circle',
      name: 'Loop Arrow',
      category: StickerCategory.arrows,
      tags: ['arrow', 'circle', 'loop', 'cycle'],
      svgContent:
          '<svg viewBox="0 0 80 80"><path d="M40 15 A25 25 0 1 1 15 40" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M20 15 L40 15 L40 35" stroke="currentColor" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ),
  ];

  static const List<StickerAsset> callouts = [
    StickerAsset(
      id: 'callout_speech',
      name: 'Speech Bubble',
      category: StickerCategory.callouts,
      tags: ['callout', 'speech', 'bubble', 'chat'],
      svgContent:
          '<svg viewBox="0 0 120 90"><rect x="10" y="10" width="100" height="55" rx="10" stroke="currentColor" stroke-width="3" fill="none"/><path d="M30 65 L25 85 L50 65" stroke="currentColor" stroke-width="3" fill="none" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'callout_thought',
      name: 'Thought Bubble',
      category: StickerCategory.callouts,
      tags: ['callout', 'thought', 'think', 'cloud'],
      svgContent:
          '<svg viewBox="0 0 120 100"><ellipse cx="60" cy="40" rx="50" ry="30" stroke="currentColor" stroke-width="3" fill="none"/><circle cx="35" cy="78" r="6" stroke="currentColor" stroke-width="3" fill="none"/><circle cx="25" cy="90" r="4" stroke="currentColor" stroke-width="3" fill="none"/></svg>',
    ),
    StickerAsset(
      id: 'callout_explosion',
      name: 'Burst Bubble',
      category: StickerCategory.callouts,
      tags: ['callout', 'explosion', 'bang', 'star'],
      svgContent:
          '<svg viewBox="0 0 100 100"><path d="M50 5 L58 35 L90 25 L70 48 L95 60 L65 62 L75 90 L50 70 L25 90 L35 62 L5 60 L30 48 L10 25 L42 35 Z" stroke="currentColor" stroke-width="2.5" fill="none" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'callout_tooltip',
      name: 'Tooltip',
      category: StickerCategory.callouts,
      tags: ['callout', 'tooltip', 'tip', 'info'],
      svgContent:
          '<svg viewBox="0 0 120 70"><rect x="10" y="10" width="100" height="40" rx="6" stroke="currentColor" stroke-width="3" fill="none"/><path d="M55 50 L60 62 L65 50" stroke="currentColor" stroke-width="3" fill="none" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'callout_info',
      name: 'Info Callout',
      category: StickerCategory.callouts,
      tags: ['callout', 'info', 'information'],
      svgContent:
          '<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40" stroke="currentColor" stroke-width="3" fill="none"/><text x="50" y="38" text-anchor="middle" font-size="24" font-weight="bold" fill="currentColor">i</text><line x1="50" y1="48" x2="50" y2="72" stroke="currentColor" stroke-width="5" stroke-linecap="round"/></svg>',
    ),
    StickerAsset(
      id: 'callout_warning',
      name: 'Warning Callout',
      category: StickerCategory.callouts,
      tags: ['callout', 'warning', 'alert', 'caution'],
      svgContent:
          '<svg viewBox="0 0 100 100"><path d="M50 10 L90 85 L10 85 Z" stroke="currentColor" stroke-width="3" fill="none" stroke-linejoin="round"/><line x1="50" y1="38" x2="50" y2="60" stroke="currentColor" stroke-width="5" stroke-linecap="round"/><circle cx="50" cy="72" r="3" fill="currentColor"/></svg>',
    ),
  ];

  static const List<StickerAsset> badges = [
    StickerAsset(
      id: 'badge_check',
      name: 'Check',
      category: StickerCategory.badges,
      tags: ['badge', 'check', 'done', 'yes'],
      svgContent:
          '<svg viewBox="0 0 80 80"><circle cx="40" cy="40" r="32" stroke="currentColor" stroke-width="3" fill="none"/><path d="M25 40 L35 52 L58 28" stroke="currentColor" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'badge_cross',
      name: 'Cross',
      category: StickerCategory.badges,
      tags: ['badge', 'cross', 'no', 'wrong'],
      svgContent:
          '<svg viewBox="0 0 80 80"><circle cx="40" cy="40" r="32" stroke="currentColor" stroke-width="3" fill="none"/><path d="M28 28 L52 52 M52 28 L28 52" stroke="currentColor" stroke-width="4" fill="none" stroke-linecap="round"/></svg>',
    ),
    StickerAsset(
      id: 'badge_star',
      name: 'Star',
      category: StickerCategory.badges,
      tags: ['badge', 'star', 'favorite'],
      svgContent:
          '<svg viewBox="0 0 80 80"><path d="M40 10 L48 32 L72 32 L52 46 L60 68 L40 54 L20 68 L28 46 L8 32 L32 32 Z" stroke="currentColor" stroke-width="3" fill="none" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'badge_flag',
      name: 'Flag',
      category: StickerCategory.badges,
      tags: ['badge', 'flag', 'mark'],
      svgContent:
          '<svg viewBox="0 0 80 80"><line x1="20" y1="15" x2="20" y2="70" stroke="currentColor" stroke-width="3" stroke-linecap="round"/><path d="M20 15 L65 25 L20 40" stroke="currentColor" stroke-width="3" fill="none" stroke-linejoin="round"/></svg>',
    ),
    StickerAsset(
      id: 'badge_todo',
      name: 'TODO',
      category: StickerCategory.badges,
      tags: ['badge', 'todo', 'task'],
      svgContent:
          '<svg viewBox="0 0 120 40"><rect x="2" y="2" width="116" height="36" rx="6" stroke="currentColor" stroke-width="2.5" fill="none"/><text x="60" y="27" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor">TODO</text></svg>',
    ),
    StickerAsset(
      id: 'badge_done',
      name: 'DONE',
      category: StickerCategory.badges,
      tags: ['badge', 'done', 'complete'],
      svgContent:
          '<svg viewBox="0 0 120 40"><rect x="2" y="2" width="116" height="36" rx="6" stroke="currentColor" stroke-width="2.5" fill="none"/><text x="60" y="27" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor">DONE</text></svg>',
    ),
    StickerAsset(
      id: 'badge_bug',
      name: 'BUG',
      category: StickerCategory.badges,
      tags: ['badge', 'bug', 'error', 'issue'],
      svgContent:
          '<svg viewBox="0 0 100 40"><rect x="2" y="2" width="96" height="36" rx="6" stroke="currentColor" stroke-width="2.5" fill="none"/><text x="50" y="27" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor">BUG</text></svg>',
    ),
    StickerAsset(
      id: 'badge_fix',
      name: 'FIX',
      category: StickerCategory.badges,
      tags: ['badge', 'fix', 'repair'],
      svgContent:
          '<svg viewBox="0 0 100 40"><rect x="2" y="2" width="96" height="36" rx="6" stroke="currentColor" stroke-width="2.5" fill="none"/><text x="50" y="27" text-anchor="middle" font-size="18" font-weight="bold" fill="currentColor">FIX</text></svg>',
    ),
  ];

  static const List<StickerAsset> emojis = [
    StickerAsset(
      id: 'emoji_thumbs_up',
      name: 'Thumbs Up',
      category: StickerCategory.emojis,
      tags: ['emoji', 'thumbs up', 'like', 'good'],
      svgContent:
          '<svg viewBox="0 0 80 80"><text x="40" y="58" text-anchor="middle" font-size="48">👍</text></svg>',
      isRecolorable: false,
    ),
    StickerAsset(
      id: 'emoji_thumbs_down',
      name: 'Thumbs Down',
      category: StickerCategory.emojis,
      tags: ['emoji', 'thumbs down', 'dislike', 'bad'],
      svgContent:
          '<svg viewBox="0 0 80 80"><text x="40" y="58" text-anchor="middle" font-size="48">👎</text></svg>',
      isRecolorable: false,
    ),
    StickerAsset(
      id: 'emoji_question',
      name: 'Question',
      category: StickerCategory.emojis,
      tags: ['emoji', 'question', 'confused'],
      svgContent:
          '<svg viewBox="0 0 80 80"><text x="40" y="58" text-anchor="middle" font-size="48">❓</text></svg>',
      isRecolorable: false,
    ),
    StickerAsset(
      id: 'emoji_exclamation',
      name: 'Exclamation',
      category: StickerCategory.emojis,
      tags: ['emoji', 'exclamation', 'important'],
      svgContent:
          '<svg viewBox="0 0 80 80"><text x="40" y="58" text-anchor="middle" font-size="48">❗</text></svg>',
      isRecolorable: false,
    ),
    StickerAsset(
      id: 'emoji_eyes',
      name: 'Eyes',
      category: StickerCategory.emojis,
      tags: ['emoji', 'eyes', 'look', 'see'],
      svgContent:
          '<svg viewBox="0 0 80 80"><text x="40" y="58" text-anchor="middle" font-size="48">👀</text></svg>',
      isRecolorable: false,
    ),
    StickerAsset(
      id: 'emoji_fire',
      name: 'Fire',
      category: StickerCategory.emojis,
      tags: ['emoji', 'fire', 'hot', 'trending'],
      svgContent:
          '<svg viewBox="0 0 80 80"><text x="40" y="58" text-anchor="middle" font-size="48">🔥</text></svg>',
      isRecolorable: false,
    ),
    StickerAsset(
      id: 'emoji_click',
      name: 'Click',
      category: StickerCategory.emojis,
      tags: ['emoji', 'click', 'cursor', 'tap'],
      svgContent:
          '<svg viewBox="0 0 80 80"><text x="40" y="58" text-anchor="middle" font-size="48">👆</text></svg>',
      isRecolorable: false,
    ),
    StickerAsset(
      id: 'emoji_100',
      name: 'Perfect',
      category: StickerCategory.emojis,
      tags: ['emoji', '100', 'perfect', 'score'],
      svgContent:
          '<svg viewBox="0 0 80 80"><text x="40" y="58" text-anchor="middle" font-size="48">💯</text></svg>',
      isRecolorable: false,
    ),
  ];

  static const List<StickerAsset> decorations = [
    StickerAsset(
      id: 'deco_underline',
      name: 'Underline',
      category: StickerCategory.decorations,
      tags: ['decoration', 'underline', 'emphasis'],
      svgContent:
          '<svg viewBox="0 0 120 20"><path d="M10 15 C30 5 50 15 70 8 C90 2 110 12 110 15" stroke="currentColor" stroke-width="4" fill="none" stroke-linecap="round"/></svg>',
    ),
    StickerAsset(
      id: 'deco_bracket_curly',
      name: 'Curly Brace',
      category: StickerCategory.decorations,
      tags: ['decoration', 'bracket', 'curly', 'code'],
      svgContent:
          '<svg viewBox="0 0 40 120"><path d="M30 10 C15 10 20 30 15 50 C10 60 10 60 15 70 C20 90 15 110 30 110" stroke="currentColor" stroke-width="3" fill="none" stroke-linecap="round"/></svg>',
    ),
    StickerAsset(
      id: 'deco_highlight_box',
      name: 'Highlight Box',
      category: StickerCategory.decorations,
      tags: ['decoration', 'highlight', 'box', 'frame'],
      svgContent:
          '<svg viewBox="0 0 120 60"><rect x="5" y="5" width="110" height="50" rx="4" stroke="currentColor" stroke-width="3" fill="none" stroke-dasharray="8 4"/></svg>',
    ),
    StickerAsset(
      id: 'deco_circle_mark',
      name: 'Circle Mark',
      category: StickerCategory.decorations,
      tags: ['decoration', 'circle', 'mark', 'highlight'],
      svgContent:
          '<svg viewBox="0 0 100 80"><ellipse cx="50" cy="40" rx="42" ry="32" stroke="currentColor" stroke-width="3" fill="none" transform="rotate(-5 50 40)"/></svg>',
    ),
    StickerAsset(
      id: 'deco_before',
      name: 'Before',
      category: StickerCategory.decorations,
      tags: ['decoration', 'before', 'compare'],
      svgContent:
          '<svg viewBox="0 0 130 40"><rect x="2" y="2" width="126" height="36" rx="6" fill="none" stroke="currentColor" stroke-width="2.5"/><text x="65" y="27" text-anchor="middle" font-size="16" font-weight="bold" fill="currentColor">BEFORE</text></svg>',
    ),
    StickerAsset(
      id: 'deco_after',
      name: 'After',
      category: StickerCategory.decorations,
      tags: ['decoration', 'after', 'compare'],
      svgContent:
          '<svg viewBox="0 0 120 40"><rect x="2" y="2" width="116" height="36" rx="6" fill="none" stroke="currentColor" stroke-width="2.5"/><text x="60" y="27" text-anchor="middle" font-size="16" font-weight="bold" fill="currentColor">AFTER</text></svg>',
    ),
  ];

  /// Get all stickers
  static List<StickerAsset> get all => [
    ...arrows,
    ...callouts,
    ...badges,
    ...emojis,
    ...decorations,
  ];

  /// Get stickers by category
  static List<StickerAsset> byCategory(StickerCategory category) {
    switch (category) {
      case StickerCategory.arrows:
        return arrows;
      case StickerCategory.callouts:
        return callouts;
      case StickerCategory.badges:
        return badges;
      case StickerCategory.emojis:
        return emojis;
      case StickerCategory.decorations:
        return decorations;
      case StickerCategory.custom:
        return []; // User custom stickers managed separately
    }
  }

  /// Search stickers by query
  static List<StickerAsset> search(String query) {
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all.where((sticker) {
      return sticker.name.toLowerCase().contains(lowerQuery) ||
          sticker.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }
}
