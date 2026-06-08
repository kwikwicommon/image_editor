abstract class ImageEditorLocalizations {
  const ImageEditorLocalizations();

  String text(String key);
  String params(String key, Map<String, String> params);
  String dimensions(double width, double height);
}

class DefaultImageEditorLocalizations extends ImageEditorLocalizations {
  const DefaultImageEditorLocalizations();

  static const Map<String, String> _messages = {
    'common.cancel': 'Cancel',
    'common.delete': 'Delete',
    'common.done': 'Done',
    'common.export': 'Export',
    'common.favorite': 'Favorite',
    'common.remove': 'Remove',
    'common.save': 'Save',
    'common.search': 'Search',
    'common.tools': 'Tools',
    'background.title': 'Background',
    'background.type': 'Type',
    'background.none': 'None',
    'background.gradient': 'Gradient',
    'background.solid': 'Solid',
    'background.image': 'Image',
    'background.pattern': 'Pattern',
    'background.imageSelected': 'Image selected',
    'background.imageMissing': 'No image selected',
    'background.padding': 'Padding',
    'background.radius': 'Radius',
    'background.shadow': 'Shadow',
    'background.titleBar': 'Title bar',
    'background.pattern.grid': 'Grid',
    'background.pattern.dots': 'Dots',
    'background.pattern.diagonalLines': 'Diagonal lines',
    'background.pattern.crosshatch': 'Crosshatch',
    'background.pattern.hexagons': 'Hexagons',
    'background.pattern.waves': 'Waves',
    'sticker.title': 'Stickers',
    'sticker.favorites': 'Favorites',
    'sticker.recent': 'Recent',
    'stickers.category.arrows': 'Arrows',
    'stickers.category.badges': 'Badges',
    'stickers.category.callouts': 'Callouts',
    'stickers.category.custom': 'Custom',
    'stickers.category.decorations': 'Decorations',
    'stickers.category.emojis': 'Emojis',
    'stickers.noResults': 'No stickers found.',
    'sticker.arrow_right': 'Right Arrow',
    'sticker.arrow_curved_right': 'Curved Arrow',
    'sticker.arrow_u_turn': 'U-Turn Arrow',
    'sticker.arrow_double': 'Double Arrow',
    'sticker.arrow_hand_point': 'Hand Pointer',
    'sticker.arrow_circle': 'Loop Arrow',
    'sticker.callout_speech': 'Speech Bubble',
    'sticker.callout_thought': 'Thought Bubble',
    'sticker.callout_explosion': 'Burst Bubble',
    'sticker.callout_tooltip': 'Tooltip',
    'sticker.callout_info': 'Info Callout',
    'sticker.callout_warning': 'Warning Callout',
    'sticker.badge_check': 'Check',
    'sticker.badge_cross': 'Cross',
    'sticker.badge_star': 'Star',
    'sticker.badge_flag': 'Flag',
    'sticker.badge_todo': 'TODO',
    'sticker.badge_done': 'DONE',
    'sticker.badge_bug': 'BUG',
    'sticker.badge_fix': 'FIX',
    'sticker.emoji_thumbs_up': 'Thumbs Up',
    'sticker.emoji_thumbs_down': 'Thumbs Down',
    'sticker.emoji_question': 'Question',
    'sticker.emoji_exclamation': 'Exclamation',
    'sticker.emoji_eyes': 'Eyes',
    'sticker.emoji_fire': 'Fire',
    'sticker.emoji_click': 'Click',
    'sticker.emoji_100': 'Perfect',
    'sticker.deco_underline': 'Underline',
    'sticker.deco_bracket_curly': 'Curly Brace',
    'sticker.deco_highlight_box': 'Highlight Box',
    'sticker.deco_circle_mark': 'Circle Mark',
    'sticker.deco_before': 'Before',
    'sticker.deco_after': 'After',
    'toolbar.select': 'Select',
    'toolbar.arrow': 'Arrow',
    'toolbar.rectangle': 'Rectangle',
    'toolbar.ellipse': 'Ellipse',
    'toolbar.text': 'Text',
    'toolbar.pencil': 'Pencil',
    'toolbar.highlighter': 'Highlighter',
    'toolbar.blur': 'Blur',
    'toolbar.counter': 'Counter',
    'toolbar.eraser': 'Eraser',
    'toolbar.crop': 'Crop',
    'toolbar.undo': 'Undo',
    'toolbar.redo': 'Redo',
    'error.invalidSourceImage': 'The source image could not be decoded.',
    'error.importReadableImage': 'Import a readable image and try again.',
    'error.invalidBackgroundImage': 'The background image could not be decoded.',
    'error.importReadableBackgroundImage':
        'Import a readable background image and try again.',
    'error.backgroundLayoutFailed': 'The background layout could not be resolved.',
    'error.checkBackgroundSettings': 'Check the background settings.',
    'error.compositedImageRenderFailed': 'The image could not be rendered.',
    'error.reduceCompositionSize': 'Reduce the output size and try again.',
    'error.compositedImageEncodeFailed': 'The image could not be encoded.',
    'error.compositeImageFailed': 'The image could not be composed.',
    'error.invalidCompositionPixelRatio': 'The pixel ratio is invalid.',
    'error.invalidCompositionBudget': 'The composition budget is invalid.',
    'error.compositionPixelRatioTooLarge':
        'The pixel ratio {ratio} exceeds the limit {limit}.',
    'error.invalidCompositionOutputSize': 'The output size is invalid.',
    'error.compositionDimensionsTooLarge':
        'The output dimensions {width}x{height} exceed {maxWidth}x{maxHeight}.',
    'error.compositionPixelsTooLarge':
        'The output pixel count {pixels} exceeds the limit {limit}.',
    'error.compositionMemoryTooLarge':
        'The estimated memory use {bytes} exceeds the limit {limit}.',
    'error.encodedImageEmpty': 'The encoded image is empty.',
    'error.tryAgain': 'Try again.',
    'error.unsupportedEncodingFormat': 'The encoding format is unsupported.',
    'error.projectPayloadInvalid': 'The project payload is invalid.',
    'error.projectUnsupportedVersion':
        'Project version {version} is newer than this package supports.',
  };

  @override
  String text(String key) {
    return _messages[key] ?? key;
  }

  @override
  String params(String key, Map<String, String> params) {
    var message = text(key);
    for (final entry in params.entries) {
      message = message.replaceAll('{${entry.key}}', entry.value);
    }
    return message;
  }

  @override
  String dimensions(double width, double height) {
    return '${width.round()} x ${height.round()}';
  }
}
