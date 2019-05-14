//
//  EditableMathUILabel.m
//
//  Created by Kostub Deshmukh on 9/2/13.
//  Copyright (C) 2013 MathChat
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import <QuartzCore/QuartzCore.h>

#import "MTEditableMathLabel.h"
#import "MTMathList.h"
#import "MTMathUILabel.h"
#import "MTMathAtomFactory.h"
#import "MTCaretView.h"
#import "MTMathList+Editing.h"
#import "MTDisplay+Editing.h"

#import "MTUnicode.h"
#import "MTMathListBuilder.h"

#import "MTFontManager.h"

@interface MTEditableMathLabel() <UIGestureRecognizerDelegate, UITextInput>

@property (nonatomic) UITapGestureRecognizer* tapGestureRecognizer;

@end

@implementation MTEditableMathLabel {
    MTCaretView* _caretView;
    MTMathListIndex* _insertionIndex;
    CGAffineTransform _flipTransform;
    NSMutableArray* _indicesToHighlight;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self initialize];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self initialize];
}

- (void) createCancelImage
{
    self.cancelImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"cross"]];
    CGRect frame = CGRectMake(self.frame.size.width - 55, (self.frame.size.height - 45)/2, 45, 45);
    self.cancelImage.frame = frame;
    [self addSubview:self.cancelImage];
    
    self.cancelImage.userInteractionEnabled = YES;
    UITapGestureRecognizer *cancelRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clearTapped:)];
    [self.cancelImage addGestureRecognizer:cancelRecognizer];
    cancelRecognizer.delegate = nil;
    self.cancelImage.hidden = YES;
}

- (void) initialize
{
    // Add tap gesture recognizer to let the user enter editing mode.
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self addGestureRecognizer:self.tapGestureRecognizer];
    self.tapGestureRecognizer.delegate = self;
    
    // Create our text storage.
    
    self.mathList =  [MTMathList new];

    self.userInteractionEnabled = YES;
    self.autoresizesSubviews = YES;
    
    // Create and set up the APLSimpleCoreTextView that will do the drawing.
    MTMathUILabel *label = [[MTMathUILabel alloc] initWithFrame:self.bounds];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:label];
    label.fontSize = 24;//30;
    label.backgroundColor = self.backgroundColor;
    label.userInteractionEnabled = NO;
    label.textAlignment = kMTTextAlignmentLeft;//kMTTextAlignmentCenter;
    self.label = label;
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0, self.bounds.size.height);
    _flipTransform = CGAffineTransformConcat(CGAffineTransformMakeScale(1.0, -1.0), transform);
    
    _caretView = [[MTCaretView alloc] initWithEditor:self];
    _caretView.caretColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    
    _indicesToHighlight = [NSMutableArray array];
    _highlightColor = [UIColor colorWithRed:0.8 green:0 blue:0.0 alpha:1.0];
    [self bringSubviewToFront:self.cancelImage];
    
    // start with an empty math list
    self.mathList = [MTMathList new];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = CGRectMake(self.frame.size.width - 55, (self.frame.size.height - 45)/2, 45, 45);
    self.cancelImage.frame = frame;
    
    // update the flip transform
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0, self.bounds.size.height);
    _flipTransform = CGAffineTransformConcat(CGAffineTransformMakeScale(1.0, -1.0), transform);
    
    [self.label layoutIfNeeded];
    [self insertionPointChanged];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    self.label.backgroundColor = backgroundColor;
}
  
- (void)setTextColor:(UIColor *)textColor
{
    self.label.textColor = textColor;
}

- (void)setFontSize:(CGFloat)fontSize
{
    self.label.fontSize = fontSize;
    _caretView.fontSize = fontSize;
    // Update the cursor position when the font size changes.
    [self insertionPointChanged];
}

- (void)updateFontSize:(CGFloat)fontSize{
    self.label.fontSize = fontSize;
    _caretView.fontSize = fontSize;
    // Update the cursor position when the font size changes.
    [self insertionPointChanged];

}
- (CGFloat)fontSize
{
    return self.label.fontSize;
}
 
- (void)latinModernFontWithSize:(CGFloat)size
{
    self.label.font = [[MTFontManager fontManager] latinModernFontWithSize:size];
}
  
- (void)xitsFontWithSize:(CGFloat)size
{
    self.label.font = [[MTFontManager fontManager] xitsFontWithSize:size];
}
  
- (void)termesFontWithSize:(CGFloat)size
{
    self.label.font = [[MTFontManager fontManager] termesFontWithSize:size];
}
  
- (void)defaultFont
{
    self.label.font = [[MTFontManager fontManager] defaultFont];
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets
{
    self.label.contentInsets = contentInsets;
}

- (UIEdgeInsets)contentInsets
{
    return self.label.contentInsets;
}

- (CGSize) mathDisplaySize
{
    return [self.label sizeThatFits:self.label.bounds.size];
}

#pragma mark - Custom user interaction

- (UIView *)inputView
{
    return self.keyboard;
}

/**
 UIResponder protocol override.
 Our view can become first responder to receive user text input.
 */
- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder
{
    BOOL canBecome = [super becomeFirstResponder];
    if (canBecome) {
        if (_insertionIndex == nil) {
            _insertionIndex = [MTMathListIndex level0Index:self.mathList.atoms.count];
        }
        
        [self.keyboard startedEditing:self];
        
        [self insertionPointChanged];
        if ([self.delegate respondsToSelector:@selector(didBeginEditing:)]) {
          [self.delegate didBeginEditing:self];
        }
        
//        if ([self.delegate respondsToSelector:@selector(didBeginEditing:withCaretView:)]) {
//            [self.delegate didBeginEditing:self withCaretView:_caretView];
//        }
    } else {
        // Sometimes it takes some time
        // [self performSelector:@selector(startEditing) withObject:nil afterDelay:0.0];
    }
    return canBecome;
}

/**
 UIResponder protocol override.
 Called when our view is being asked to resign first responder state.
 */
- (BOOL)resignFirstResponder
{
    BOOL val = YES;
    if ([self isFirstResponder]) {
        [self.keyboard finishedEditing:self];
        val = [super resignFirstResponder];
        [self insertionPointChanged];
        if ([self.delegate respondsToSelector:@selector(didEndEditing:)]) {
            [self.delegate didEndEditing:self];
        }
    }
    return val;
}

/**
 UIGestureRecognizerDelegate method.
 Called to determine if we want to handle a given gesture.
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch
{
    // If gesture touch occurs in our view, we want to handle it
    return YES;
    //return (touch.view == self);
}

- (void) startEditing
{
    if (![self isFirstResponder]) {
        // Become first responder state (which shows software keyboard, if applicable).
        [self becomeFirstResponder];
    }
}

- (void) endEditing
{
    if ([self isFirstResponder]) {
        // Become first responder state (which shows software keyboard, if applicable).
        [self resignFirstResponder];
    }
}

/**
 Our tap gesture recognizer selector that enters editing mode, or if already in editing mode, updates the text insertion point.
 */
- (void)tap:(UITapGestureRecognizer *)tap
{
    if (![self isFirstResponder]) {
        _insertionIndex = nil;
        [_caretView showHandle:NO];
        [self startEditing];
    } else {
        // If already editing move the cursor and show handle
        _insertionIndex = [self closestIndexToPoint:[tap locationInView:self]];
        if (_insertionIndex == nil) {
            _insertionIndex = [MTMathListIndex level0Index:self.mathList.atoms.count];
        }
        [_caretView showHandle:NO];
        [self insertionPointChanged];
    }
}

- (void)clearTapped:(UITapGestureRecognizer *)tap
{
    [self clear];
}

- (void)clear
{
    self.mathList = [MTMathList new];
    [self insertionPointChanged];
}

- (void)moveCaretToPoint:(CGPoint)point
{
    _insertionIndex = [self closestIndexToPoint:point];
    [_caretView showHandle:NO];
    [self insertionPointChanged];
}

+ (void) clearPlaceholders:(MTMathList*) mathList
{
    for (MTMathAtom* atom in mathList.atoms) {
        if (atom.type == kMTMathAtomPlaceholder) {
            atom.nucleus = MTSymbolWhiteSquare;
        }
        
        if (atom.superScript) {
            [self clearPlaceholders:atom.superScript];
        }
        if (atom.subScript) {
            [self clearPlaceholders:atom.subScript];
        }
        if (atom.beforeSubScript) {
            [self clearPlaceholders:atom.beforeSubScript];
        }
        
        if (atom.type == kMTMathAtomRadical) {
            MTRadical *rad = (MTRadical *) atom;
            [self clearPlaceholders:rad.degree];
            [self clearPlaceholders:rad.radicand];
        }
        
        if (atom.type == kMTMathAtomFraction) {
            MTFraction* frac = (MTFraction*) atom;
            [self clearPlaceholders:frac.numerator];
            [self clearPlaceholders:frac.denominator];
            [self clearPlaceholders:frac.whole];
        }
        if (atom.type == kMTMathAtomOrderedPair) {
            MTOrderedPair *pair = (MTOrderedPair *) atom;
            [self clearPlaceholders:pair.leftOperand];
            [self clearPlaceholders:pair.rightOperand];
        }
        if (atom.type == kMTMathAtomBinomialMatrix) {
            MTBinomialMatrix *matrix = (MTBinomialMatrix *) atom;
            [self clearPlaceholders:matrix.row0Col0];
            [self clearPlaceholders:matrix.row0Col1];
            [self clearPlaceholders:matrix.row1Col0];
            [self clearPlaceholders:matrix.row1Col1];
            
        }
        if (atom.type == kMTMathAtomAbsoluteValue) {
            MTAbsoluteValue *absValue = (MTAbsoluteValue *) atom;
            [self clearPlaceholders:absValue.absHolder];
        }

        if(atom.type == kMTMathAtomAccent){
            MTAccent *accent = (MTAccent *)atom;
            [self clearPlaceholders:accent.innerList];
        }
        if (atom.type == kMTMathAtomExponentBase) {
            MTExponent *exp = (MTExponent *) atom;
            [self clearPlaceholders:exp.exponent];
            [self clearPlaceholders:exp.expSuperScript];
            [self clearPlaceholders:exp.expSubScript];
            [self clearPlaceholders:exp.prefixedSubScript];
        }
        if(atom.type == kMTMathAtomInner){
            MTInner *inner = (MTInner *)atom;
            [self clearPlaceholders:inner.innerList];
        }
        if(atom.type == kMTMathAtomLargeOperator){
            MTLargeOperator *largeOp = (MTLargeOperator *)atom;
            [self clearPlaceholders:largeOp.holder];
        }
    }
}
- (void)setMathList:(MTMathList *)mathList
{
    if (mathList) {
        _mathList = mathList;
    } else {
        // clear
        _mathList = [MTMathList new];
    }
    self.label.mathList = self.mathList;
    _insertionIndex = [MTMathListIndex level0Index:mathList.atoms.count];
    [self insertionPointChanged];
}

- (void)setLatex:(NSString *)latex {
    self.label.latex = latex;
    MTMathList *mathList = self.label.mathList;
    if (mathList) {
        _mathList = mathList;
    } else {
        // clear
        _mathList = [MTMathList new];
    }
    _insertionIndex = [MTMathListIndex level0Index:mathList.atoms.count];
    [self insertionPointChanged];
}

// Helper method to update caretView when insertion point/selection changes.
- (void) insertionPointChanged
{
    // If not in editing mode, we don't show the caret.
    if (![self isFirstResponder]) {
        [_caretView removeFromSuperview];
        self.cancelImage.hidden = YES;
        return;
    }
    [MTEditableMathLabel clearPlaceholders:self.mathList];
    MTMathAtom* atom = [self.mathList atomAtListIndex:_insertionIndex];
    if (atom.type == kMTMathAtomPlaceholder) {
        atom.nucleus = MTSymbolBlackSquare;
        if (_insertionIndex.finalSubIndexType == kMTSubIndexTypeNucleus) {
            // If the insertion index is inside a placeholder, move it out.
            _insertionIndex = _insertionIndex.levelDown;
        }
        // TODO - disable caret
    } else {
        MTMathListIndex* previousIndex = _insertionIndex.previous;
        atom = [self.mathList atomAtListIndex:previousIndex];
        if (atom.type == kMTMathAtomPlaceholder && atom.superScript == nil && atom.subScript == nil) {
            _insertionIndex = previousIndex;
            atom.nucleus = MTSymbolBlackSquare;
            // TODO - disable caret
        }
    }
    
    [self setKeyboardMode];
    
    /*
     Find the insert point rect and create a caretView to draw the caret at this position.
     */
    
    CGPoint caretPosition = [self caretRectForIndex:_insertionIndex];
    // Check tht we were returned a valid position before displaying a caret there.
    if (CGPointEqualToPoint(caretPosition, CGPointMake(-1, -1))) {
        return;
    }
    
    // caretFrame is in the flipped coordinate system, flip it back
    _caretView.position = CGPointApplyAffineTransform(caretPosition, _flipTransform);
    if (_caretView.superview == nil) {
        [self addSubview:_caretView];
        [self setNeedsDisplay];
    }
    
    // when a caret is displayed, the X symbol should be as well
    self.cancelImage.hidden = NO;
    
    // Set up a timer to "blink" the caret.
    [_caretView delayBlink];
    [self.label setNeedsLayout];
}


- (void) setKeyboardMode
{
    self.keyboard.exponentHighlighted = NO;
    self.keyboard.radicalHighlighted = NO;
    self.keyboard.squareRootHighlighted = NO;

    if ([_insertionIndex hasSubIndexOfType:kMTSubIndexTypeSuperscript]) {
        self.keyboard.exponentHighlighted = YES;
        self.keyboard.equalsAllowed = NO;
    }
    if (_insertionIndex.subIndexType == kMTSubIndexTypeNumerator) {
        self.keyboard.equalsAllowed = false;
    } else if (_insertionIndex.subIndexType == kMTSubIndexTypeDenominator) {
        //self.keyboard.fractionsAllowed = false;
        //self.keyboard.equalsAllowed = false;
    }
    
    // handle radicals
    if (_insertionIndex.subIndexType == kMTSubIndexTypeDegree) {
        self.keyboard.radicalHighlighted = YES;
    } else if (_insertionIndex.subIndexType == kMTSubIndexTypeRadicand) {
        self.keyboard.squareRootHighlighted = YES;
    }
}

- (void)insertMathList:(MTMathList *)list atPoint:(CGPoint)point
{
    MTMathListIndex* detailedIndex = [self closestIndexToPoint:point];
    // insert at the given index - but don't consider sublevels at this point
    MTMathListIndex* index = [MTMathListIndex level0Index:detailedIndex.atomIndex];
    for (MTMathAtom* atom in list.atoms) {
        [self.mathList insertAtom:atom atListIndex:index];
        index = index.next;
    }
    self.label.mathList = self.mathList;
    _insertionIndex = index;  // move the index to the end of the new list.
    [self insertionPointChanged];
}

- (void) enableTap:(BOOL) enabled
{
    self.tapGestureRecognizer.enabled = enabled;
}

#pragma mark - UIKeyInput

static const unichar kMTUnicodeGreekLowerStart = 0x03B1;
static const unichar kMTUnicodeGreekLowerEnd = 0x03C9;
static const unichar kMTUnicodeGreekCapitalStart = 0x0391;
static const unichar kMTUnicodeGreekCapitalEnd = 0x03A9;

- (MTMathAtom*) atomForCharacter:(unichar) ch
{
    NSString *chStr = [NSString stringWithCharacters:&ch length:1];
    
    // Ensure all symbols are included
    if ([self.delegate respondsToSelector:@selector(isDefaultKeyboard)]) {
        if ([self.delegate isDefaultKeyboard] == true) {
            return [MTMathAtom atomWithType:kMTMathAtomOrdinary value:chStr];
        }
    }
    if ([chStr isEqualToString:MTSymbolMultiplication]) {
        return [MTMathAtomFactory times];
    } else if ([chStr isEqualToString:MTSymbolSquareRoot]) {
        return [MTMathAtomFactory placeholderSquareRoot];
    } else if ([chStr isEqualToString:MTSymbolInfinity]) {
        return [MTMathAtom atomWithType:kMTMathAtomOrdinary value:chStr];
    } else if ([chStr isEqualToString:MTSymbolDegree]) {
        return [MTMathAtom atomWithType:kMTMathAtomOrdinary value:chStr];
    } else if ([chStr isEqualToString:MTSymbolAngle]) {
        return [MTMathAtom atomWithType:kMTMathAtomOrdinary value:chStr];
    } else if ([chStr isEqualToString:MTSymbolDivision]) {
        return [MTMathAtomFactory divide];
    } else if ([chStr isEqualToString:MTSymbolFractionSlash]) {
        return [MTMathAtomFactory placeholderFraction];
    } else if (ch == '(' || ch == '[' || ch == '{') {
        return [MTMathAtom atomWithType:kMTMathAtomOpen value:chStr];
    } else if (ch == ')' || ch == ']' || ch == '}') {
        return [MTMathAtom atomWithType:kMTMathAtomClose value:chStr];
    } else if (ch == ',' || ch == ';') {
        return [MTMathAtom atomWithType:kMTMathAtomPunctuation value:chStr];
    } else if (ch == '=' || ch == '<' || ch == '>' || ch == ':' || [chStr isEqualToString:MTSymbolGreaterEqual] || [chStr isEqualToString:MTSymbolLessEqual]) {
        return [MTMathAtom atomWithType:kMTMathAtomRelation value:chStr];
    } else if (ch == '+' || ch == '-') {
        return [MTMathAtom atomWithType:kMTMathAtomBinaryOperator value:chStr];
    } else if (ch == '*') {
        return [MTMathAtomFactory times];
    } else if (ch == '/') {
        return [MTMathAtomFactory divide];
    } else if ([self isNumeric:ch]) {
        return [MTMathAtom atomWithType:kMTMathAtomNumber value:chStr];
    } else if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        return [MTMathAtom atomWithType:kMTMathAtomVariable value:chStr];
    } else if (ch >= kMTUnicodeGreekStart && ch <= kMTUnicodeGreekEnd) {
        // All greek chars are rendered as variables.
        return [MTMathAtom atomWithType:kMTMathAtomVariable value:chStr];
    } else if (ch >= kMTUnicodeCapitalGreekStart && ch <= kMTUnicodeCapitalGreekEnd) {
        // Including capital greek chars
        return [MTMathAtom atomWithType:kMTMathAtomVariable value:chStr];
    } /*else if (ch < 0x21 || ch > 0x7E || ch == '\'' || ch == '~') {
       // not ascii
       return nil;
       } */
    else {
           // just an ordinary character
           return [MTMathAtom atomWithType:kMTMathAtomOrdinary value:chStr];
       }
}

- (BOOL) isNumeric:(unichar) ch
{
    return ch == '.' || (ch >= '0' && ch <= '9');
}

- (void) handleExponentButton:(NSString*)scriptType
{
    MTMathListIndex *current = _insertionIndex;
    MTMathListIndex *previousIndex = _insertionIndex.previous;
    MTMathAtom *previousAtom = [self.mathList atomAtListIndex:previousIndex];
    MTExponent* exp = [MTExponent new];
    exp.exponent = [MTMathList new];
    [exp.exponent addAtom:[MTMathAtomFactory placeholder]];
    
    if([scriptType isEqualToString:@"Superscript"]){
        exp.expSuperScript = [MTMathList new];
        [exp.expSuperScript addAtom:[MTMathAtomFactory placeholder]];
        if (previousAtom != nil && previousIndex != nil) {
            NSString *nucleus = previousAtom.stringValue;
            if ([nucleus isEqualToString:@")"] || [nucleus isEqualToString:@"}"] || [nucleus isEqualToString:@"]"]) {
                NSString *substring = [self captureTextWithinBraces];
                if (substring.length > 0) {
                    MTMathList *expMathList = [MTMathListBuilder buildFromString:substring];
                    if (expMathList != nil) {
                        [exp.exponent removeAtomAtIndex:0];
                        for(int i = 0; i<expMathList.atoms.count; i++){
                            [exp.exponent addAtom:expMathList.atoms[i]];
                            MTMathListIndex *prevIndex = current.previous;
                            if (prevIndex != nil) {
                                current = prevIndex;
                                [self.mathList removeAtomAtListIndex:current];
                            }
                        }
                    }
                }
            } else {
                [self prefixAtomForExponent:exp previousAtom:previousAtom];
                current = previousIndex;
            }
            _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:exp.expSuperScript.atoms.count] type:kMTSubIndexTypeExpSuperscript];
        }
    }
    else if([scriptType isEqualToString:@"Subscript"]){
        exp.expSubScript = [MTMathList new];
        [exp.expSubScript addAtom:[MTMathAtomFactory placeholder]];
        if (previousAtom != nil && previousIndex != nil) {
            [self prefixAtomForExponent:exp previousAtom:previousAtom];
            current = previousIndex;
            _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:exp.expSubScript.atoms.count] type:kMTSubIndexTypeExpSubscript];
        }
    }
    else if([scriptType isEqualToString:@"SubscriptBeforeAndAfter"]){
        exp.expSubScript = [MTMathList new];
        [exp.expSubScript addAtom:[MTMathAtomFactory placeholder]];
        exp.prefixedSubScript = [MTMathList new];
        [exp.prefixedSubScript addAtom:[MTMathAtomFactory placeholder]];
        if (previousAtom != nil && previousIndex != nil) {
            [self prefixAtomForExponent:exp previousAtom:previousAtom];
            current = previousIndex;
            _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:exp.prefixedSubScript.atoms.count] type:kMTSubIndexTypeExpBeforeSubscript];
        }
    }
    else if([scriptType isEqualToString:@"SuperscriptAndSubscript"]){
        
        exp.expSuperScript = [MTMathList new];
        [exp.expSuperScript addAtom:[MTMathAtomFactory placeholder]];
        exp.expSubScript = [MTMathList new];
        [exp.expSubScript addAtom:[MTMathAtomFactory placeholder]];
        if (previousAtom != nil && previousIndex != nil) {
            [self prefixAtomForExponent:exp previousAtom:previousAtom];
            current = previousIndex;
            _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:exp.expSuperScript.atoms.count] type:kMTSubIndexTypeExpSuperscript];
        }
    }
    if (![self updatePlaceholderIfPresent:exp]) {
        [self.mathList insertAtom:exp atListIndex:current];
    }
    
    if (_insertionIndex.subIndexType == kMTSubIndexTypeExpSuperscript) {
        _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:exp.expSuperScript.atoms.count] type:kMTSubIndexTypeExpSuperscript];
    } else if(_insertionIndex.subIndexType == kMTSubIndexTypeExpSubscript){
        _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:exp.expSubScript.atoms.count] type:kMTSubIndexTypeExpSubscript];
    } else if(_insertionIndex.subIndexType == kMTSubIndexTypeExpBeforeSubscript){
        _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:exp.prefixedSubScript.atoms.count] type:kMTSubIndexTypeExpBeforeSubscript];
    } else {
        _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:exp.exponent.atoms.count] type:kMTSubIndexTypeExponent];
    }
}

- (void)prefixAtomForExponent:(MTExponent*)exp previousAtom: (MTMathAtom*)prevAtom {
    [exp.exponent removeAtomAtIndex:0];
    [exp.exponent addAtom:prevAtom];
    [self.mathList removeAtomAtListIndex:_insertionIndex.previous];
}

- (NSString*)captureTextWithinBraces {
    NSString *text = @"";
    for (int i = 0; i < self.mathList.atoms.count; i++) {
        NSString *nucleus = [_mathList.atoms objectAtIndex:i].stringValue;
        text = [text stringByAppendingString:nucleus];
    }
    NSString *substring = nil;
    NSUInteger len = [text length];
    unichar buffer[len];
    int charStartLocation = 0;
    int charEndLocation = 0;
    BOOL isCharStarted = false;
    [text getCharacters:buffer range:NSMakeRange(0, len)];
    unichar endChar = buffer[len-1];
    unichar startChar;
    if (endChar == '}') {
        startChar = '{';
    } else if (endChar == ')') {
        startChar = '(';
    } else if (endChar == ']') {
        startChar = '[';
    } else {
        endChar = nil;
    }
    for(int i = 0; i < len; ++i) {
        unichar currentChar = buffer[i];
        if (currentChar == startChar && isCharStarted == false) {
            charStartLocation = i;
            isCharStarted = true;
        }
        if (currentChar == endChar && i == len-1) {
            charEndLocation = len - charStartLocation;
        }
    }
    NSRange charRange = NSMakeRange(charStartLocation, charEndLocation);
    NSString *capturedText = [[NSString alloc] initWithString:[text substringWithRange:charRange]];
    return capturedText;
}

- (void) handlePrime:(NSString *)type
{
  MTMathAtom *prime = [MTMathAtomFactory atomForLatexSymbolName: type];
  [self.mathList insertAtom:prime atListIndex:_insertionIndex];
  _insertionIndex = _insertionIndex.next;
}

- (void) handleSubscriptButton
{
    // Create an empty atom and move the insertion index up.
    MTMathAtom* emptyAtom = [MTMathAtomFactory placeholder];
    emptyAtom.subScript = [MTMathList new];
    [emptyAtom.subScript addAtom:[MTMathAtomFactory placeholder]];
    
    if (![self updatePlaceholderIfPresent:emptyAtom]) {
        // If the placeholder hasn't been updated then insert it.
        [self.mathList insertAtom:emptyAtom atListIndex:_insertionIndex];
    }
    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeNucleus];
    
}

// If the index is in a radical, subscript, or exponent, fetches the next index after the root atom.
- (MTMathListIndex *) getIndexAfterSpecialStructure:(MTMathListIndex *) index type:(MTMathListSubIndexType)type
{
    MTMathListIndex *nextIndex = index;
    while ([nextIndex hasSubIndexOfType:type]){
        nextIndex = nextIndex.levelDown;
    }
    
    //Point to just after this node.
    return nextIndex.next;
}

- (void) handleSlashButton
{
    // special / handling - makes the thing a fraction
    MTMathList* numerator = [MTMathList new];
    MTMathListIndex* current = _insertionIndex;
    for (; !current.isAtBeginningOfLine; current = current.previous) {
        MTMathAtom* atom = [self.mathList atomAtListIndex:current.previous];
        if (atom.type != kMTMathAtomNumber && atom.type != kMTMathAtomVariable) {
            // we don't put this atom on the fraction
            break;
        } else {
            // add the number to the beginning of the list
            [numerator insertAtom:atom atIndex:0];
        }
    }
    if (current.atomIndex == _insertionIndex.atomIndex) {
        // so we didn't really find any numbers before this, so make the numerator 1
        [numerator addAtom:[self atomForCharacter:'1']];
        if (!current.isAtBeginningOfLine) {
            MTMathAtom* prevAtom = [self.mathList atomAtListIndex:current.previous];
            if (prevAtom.type == kMTMathAtomFraction) {
                // add a times symbol
                [self.mathList insertAtom:[MTMathAtomFactory times] atListIndex:current];
                current = current.next;
            }
        }
    } else {
        // delete stuff in the mathlist from current to _insertionIndex
        [self.mathList removeAtomsInListIndexRange:[MTMathListRange makeRange:current length:_insertionIndex.atomIndex - current.atomIndex]];
    }
    
    // create the fraction
    MTFraction *frac = [MTFraction new];
    frac.denominator = [MTMathList new];
    [frac.denominator addAtom:[MTMathAtomFactory placeholder]];
    frac.numerator = numerator;
    
    // insert it
    [self.mathList insertAtom:frac atListIndex:current];
    // update the insertion index to go the denominator
    _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeDenominator];
}

- (void) handleAccent:(NSString*) accent {
    MTAccent *accentAtom = [MTMathAtomFactory accentWithName:accent];
    MTMathAtom* emptyAtom = [MTMathAtomFactory placeholder];
    
    MTMathList* mathList = [[MTMathList alloc] init];
    [mathList addAtom:emptyAtom];
    accentAtom.innerList = mathList;
    
    if (![self updatePlaceholderIfPresent:accentAtom]) {
        // If the placeholder hasn't been updated then insert it.
        [self.mathList insertAtom:accentAtom atListIndex:_insertionIndex];
    }
    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeOverbar];
    
}



-(void) handleLargeOperator:(NSString*) first second:(NSString*) second unicode:(NSString *)unicodeChar {
    MTLargeOperator* largeOp = [[MTLargeOperator alloc] initWithValue:unicodeChar limits:true];
    
    if (![unicodeChar isEqualToString:@"lim"]) {
        
        largeOp.superScript = [MTMathList new];
        [largeOp.superScript addAtom:[MTMathAtomFactory placeholder]];
        largeOp.subScript = [MTMathList new];
        [largeOp.subScript addAtom:[MTMathAtomFactory placeholder]];
        if (![self updatePlaceholderIfPresent:largeOp]) {
            // If the placeholder hasn't been updated then insert it.
            [self.mathList insertAtom:largeOp atListIndex:_insertionIndex];
        }
        _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeSuperscript];
    }
    else {
        
        largeOp.subScript = [MTMathList new];
        [largeOp.subScript addAtom:[MTMathAtomFactory placeholder]];
        if (![self updatePlaceholderIfPresent:largeOp]) {
            // If the placeholder hasn't been updated then insert it.
            [self.mathList insertAtom:largeOp atListIndex:_insertionIndex];
        }
        _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeSubscript];
    }
}

#pragma mark MTInner Methods

-(void)handleLeftBoundaryOperator:(NSString *)operator {
    
    if(_insertionIndex.endIndex.subIndexType == kMTSubIndexTypeInner){
        MTInner *parentInner = (MTInner*)[self.mathList retrieveAtomAtListIndex:_insertionIndex];
        MTMathList *parentListForInner = [self.mathList retrieveParentMathListForInner:_insertionIndex];
        NSMutableArray *innerContent = [NSMutableArray arrayWithArray:parentInner.innerList.atoms];
        if(innerContent.count == 1){
            MTMathAtom *placeHolder = [innerContent lastObject];
            if(placeHolder.type == kMTMathAtomPlaceholder){
                if(parentInner.leftBoundary == nil){
                    parentInner.leftBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:operator];
                } else{
                    [self createInnerWithOperator:operator];
                }
                return;
            }
        }
        NSMutableArray *slicedContent = [[NSMutableArray alloc] init];
        [innerContent enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
            if (_insertionIndex.endIndex.subIndex.atomIndex > idx)
            {
                [slicedContent addObject:[innerContent objectAtIndex:idx]];
            }
        }];
        if(parentInner.leftBoundary != nil){
            MTInner *inner = [MTInner new];
            inner.leftBoundary = parentInner.leftBoundary;
            inner.innerList = [MTMathList mathListWithAtomsArray:slicedContent];
            [(parentListForInner)?parentListForInner:self.mathList insertAtom:inner atIndex:_insertionIndex.endIndex.atomIndex];
        }
        else {
            for (int p = 0; p < slicedContent.count; p++){
                [(parentListForInner)?parentListForInner:self.mathList insertAtom:[slicedContent objectAtIndex:p] atIndex:_insertionIndex.endIndex.atomIndex+p];
            }
        }
        [parentInner.innerList removeAtomsInRange:NSMakeRange(0,_insertionIndex.endIndex.subIndex.atomIndex)];
        parentInner.leftBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:operator];
        if((parentInner.innerList) && (parentInner.innerList.atoms.count == 0)){
            [parentInner.innerList addAtom:[MTMathAtomFactory placeholder]];
        }
        NSUInteger innerPosition = [(parentListForInner)?parentListForInner.atoms:self.mathList.atoms indexOfObject:parentInner];
        _insertionIndex.endIndex.atomIndex = innerPosition;
        _insertionIndex.endIndex.subIndex.atomIndex = 0;
    }
    else{
        MTMathAtom *nextAtom = [self.mathList atomAtListIndex:_insertionIndex];
        if(nextAtom.type == kMTMathAtomInner){
            MTInner *prevInner = (MTInner*)nextAtom;
            if(prevInner.leftBoundary == nil){
                prevInner.leftBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:operator];
                return;
            }
        }
        [self createInnerWithOperator:operator];
    }
}

- (void)createInnerWithOperator:(NSString*)operatorType{
    MTInner *inner = [MTInner new];
    if([operatorType isEqualToString:@"("] || [operatorType isEqualToString:@"{"] || [operatorType isEqualToString:@"["]){
        inner.leftBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:operatorType];
    } else {
        inner.rightBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:operatorType];
    }
    inner.innerList = [MTMathList new];
    [inner.innerList addAtom:[MTMathAtomFactory placeholder]];
    if (![self updatePlaceholderIfPresent:inner]) {
        [self.mathList insertAtom:inner atListIndex:_insertionIndex];
    }
    // update the insertion index
    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeInner];
}
-(void)handleRightBoundaryOperator:(NSString *) operator {
    
    if(_insertionIndex.endIndex.subIndexType == kMTSubIndexTypeInner){
        MTInner *parentInner = (MTInner*)[self.mathList retrieveAtomAtListIndex:_insertionIndex];
        MTMathList *parentListForInner = [self.mathList retrieveParentMathListForInner:_insertionIndex];
        NSMutableArray *innerContent = [NSMutableArray arrayWithArray:parentInner.innerList.atoms];
        if(innerContent.count == 1){
            MTMathAtom *placeHolder = [innerContent lastObject];
            if(placeHolder.type == kMTMathAtomPlaceholder){
                if(parentInner.rightBoundary == nil){
                    parentInner.rightBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:operator];
                } else{
                    [self createInnerWithOperator:operator];
                }
                return;
            }
        }
        NSMutableArray *slicedContent = [[NSMutableArray alloc] init];
        [innerContent enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
            if (_insertionIndex.endIndex.subIndex.atomIndex <= idx)
            {
                [slicedContent addObject:[innerContent objectAtIndex:idx]];
            }
        }];
        if(parentInner.rightBoundary != nil){
            MTInner *inner = [MTInner new];
            inner.rightBoundary = parentInner.rightBoundary;
            inner.innerList = [MTMathList mathListWithAtomsArray:slicedContent];
            [(parentListForInner)?parentListForInner:self.mathList insertAtom:inner atIndex:_insertionIndex.endIndex.atomIndex+1];
        }
        else {
            for (int p = 1; p <= slicedContent.count; p++){
                [(parentListForInner)?parentListForInner:self.mathList insertAtom:[slicedContent objectAtIndex:p-1] atIndex:_insertionIndex.endIndex.atomIndex+p];
            }
        }
        int atomsCount = (int)_insertionIndex.endIndex.subIndex.atomIndex;
        int totalCount = (int)parentInner.innerList.atoms.count;
        [parentInner.innerList removeAtomsInRange:NSMakeRange(atomsCount, totalCount-atomsCount)];
        parentInner.rightBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:operator];
        if((parentInner.innerList) && (parentInner.innerList.atoms.count == 0)){
            [parentInner.innerList addAtom:[MTMathAtomFactory placeholder]];
        }
        NSUInteger innerPosition = [(parentListForInner)?parentListForInner.atoms:self.mathList.atoms indexOfObject:parentInner];
        _insertionIndex.endIndex.atomIndex = innerPosition;
        _insertionIndex = _insertionIndex.levelDownToNextLayout;
        [self levelDownToInterAtoms:nil];
    }
    else{
        MTMathListIndex *prevIndex = _insertionIndex.previous;
        MTMathAtom *prevAtom = [self.mathList atomAtListIndex:prevIndex];
        if(prevAtom.type == kMTMathAtomInner){
            MTInner *prevInner = (MTInner*)prevAtom;
            if(prevInner.rightBoundary == nil){
                prevInner.rightBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:operator];
                return;
            }
        }
        [self createInnerWithOperator:operator];
    }
}

-(void) handlePair:(NSString*) accent {
    
    // create the pair
    MTOrderedPair *orderedPair = [MTOrderedPair new];
    orderedPair.leftOperand = [MTMathList new];
    [orderedPair.leftOperand addAtom:[MTMathAtomFactory placeholder]];
    orderedPair.rightOperand = [MTMathList new];;
    [orderedPair.rightOperand addAtom:[MTMathAtomFactory placeholder]];
    // insert it
    if (![self updatePlaceholderIfPresent:orderedPair]) {
        [self.mathList insertAtom:orderedPair atListIndex:_insertionIndex];
    }
    // update the insertion index to go the left operand
    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:1] type:kMTSubIndexTypeLeftOperand];
}

-(void) handleMatrix:(NSString*) accent {
    
    // create the matrix
    MTBinomialMatrix *matrix = [MTBinomialMatrix new];
    matrix.row0Col0 = [MTMathList new];
    [matrix.row0Col0 addAtom:[MTMathAtomFactory placeholder]];
    
    matrix.row0Col1 = [MTMathList new];
    [matrix.row0Col1 addAtom:[MTMathAtomFactory placeholder]];
    
    matrix.row1Col0 = [MTMathList new];
    [matrix.row1Col0 addAtom:[MTMathAtomFactory placeholder]];
    
    matrix.row1Col1 = [MTMathList new];
    [matrix.row1Col1 addAtom:[MTMathAtomFactory placeholder]];
    
    if([accent isEqualToString:@"vmatrix"]){
        matrix.open = @"|";
        matrix.close = @"|";
    }
    else if([accent isEqualToString:@"bmatrix"]){
        matrix.open = @"[";
        matrix.close = @"]";
    }
    // insert it
    if (![self updatePlaceholderIfPresent:matrix]) {
        [self.mathList insertAtom:matrix atListIndex:_insertionIndex];
    }
    // update the insertion index
    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeRow0Col0];
    
}


- (MTMathListIndex *) getOutOfRadical:(MTMathListIndex *)index {
    if ([index hasSubIndexOfType:kMTSubIndexTypeDegree]) {
        index = [self getIndexAfterSpecialStructure:index type:kMTSubIndexTypeDegree];
    }
    if ([index hasSubIndexOfType:kMTSubIndexTypeRadicand]) {
        index = [self getIndexAfterSpecialStructure:index type:kMTSubIndexTypeRadicand];
    }
    return index;
}

- (void)handleRadical:(BOOL)withDegreeButtonPressed {
    MTRadical *rad;
    MTMathListIndex *current = _insertionIndex;
    
    if ([current hasSubIndexOfType:kMTSubIndexTypeDegree] || [current hasSubIndexOfType:kMTSubIndexTypeRadicand]) {
        rad = self.mathList.atoms[current.atomIndex];
        if (withDegreeButtonPressed) {
            if (!rad.degree) {
                rad.degree = [MTMathList new];
                [rad.degree addAtom:[MTMathAtomFactory placeholder]];
                _insertionIndex = [[current levelDown] levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeDegree];
            } else {
                // The radical the cursor is at has a degree. If the cursor is in the radicand, move the cursor to the degree
                if ([current hasSubIndexOfType:kMTSubIndexTypeRadicand]) {
                    // If the cursor is at the radicand, switch it to the degree
                    _insertionIndex = [[current levelDown] levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeDegree];
                } else {
                    // If the cursor is at the degree, get out of the radical
                    _insertionIndex = [self getOutOfRadical:current];
                }
            }
        } else {
            if ([current hasSubIndexOfType:kMTSubIndexTypeDegree]) {
                // If the radical the cursor at has a degree, and the cursor is at the degree, move the cursor to the radicand.
                _insertionIndex = [[current levelDown] levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeRadicand];
            } else {
                // If the cursor is at the radicand, get out of the radical.
                _insertionIndex = [self getOutOfRadical:current];
            }
        }
    } else {
        if (withDegreeButtonPressed) {
            rad = [MTMathAtomFactory placeholderRadical];
            
            if (![self updatePlaceholderIfPresent:rad]) {
                [self.mathList insertAtom:rad atListIndex:current];
            }
            _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeDegree];
        } else {
            rad = [MTMathAtomFactory placeholderSquareRoot];
            
            if (![self updatePlaceholderIfPresent:rad]) {
                [self.mathList insertAtom:rad atListIndex:current];
            }
            
            _insertionIndex = [current levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeRadicand];
        }
    }
    
}

- (void) handleSuperSubButton
{
    // Create an empty atom and move the insertion index up.
    MTMathAtom* emptyAtom = [MTMathAtomFactory placeholder];
    emptyAtom.superScript = [MTMathList new];
    [emptyAtom.superScript addAtom:[MTMathAtomFactory placeholder]];
    emptyAtom.subScript = [MTMathList new];
    [emptyAtom.subScript addAtom:[MTMathAtomFactory placeholder]];
    if (![self updatePlaceholderIfPresent:emptyAtom]) {
        // If the placeholder hasn't been updated then insert it.
        [self.mathList insertAtom:emptyAtom atListIndex:_insertionIndex];
    }
    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeNucleus];
    //_insertionIndex = [MTMathListIndex indexAtLocation:newAtomIndex+1 withSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeNucleus];
    
}

- (void)handleSubscriptBeforeAndAfter
{
    // Create an empty atom and move the insertion index up.
    MTMathAtom* emptyAtom = [MTMathAtomFactory placeholder];
    emptyAtom.subScript = [MTMathList new];
    [emptyAtom.subScript addAtom:[MTMathAtomFactory placeholder]];
    emptyAtom.beforeSubScript = [MTMathList new];
    [emptyAtom.beforeSubScript addAtom:[MTMathAtomFactory placeholder]];
    
    if (![self updatePlaceholderIfPresent:emptyAtom]) {
        // If the placeholder hasn't been updated then insert it.
        [self.mathList insertAtom:emptyAtom atListIndex:_insertionIndex];
    }
    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeBeforeSubscript];
    
}

- (void) removePlaceholderIfPresent
{
    MTMathAtom* current = [self.mathList atomAtListIndex:_insertionIndex];
    if (current.type == kMTMathAtomPlaceholder) {
        // remove this element - the inserted text replaces the placeholder
        [self.mathList removeAtomAtListIndex:_insertionIndex];
    }
}

// Returns true if updated
- (BOOL) updatePlaceholderIfPresent:(MTMathAtom*) atom
{
    MTMathAtom* current = [self.mathList atomAtListIndex:_insertionIndex];
    if (current.type == kMTMathAtomPlaceholder) {
        if (current.superScript) {
            atom.superScript = current.superScript;
        }
        if (current.subScript) {
            atom.subScript = current.subScript;
        }
        if (current.beforeSubScript) {
            atom.beforeSubScript = current.beforeSubScript;
        }
        // remove the placeholder and replace with atom.
        [self.mathList removeAtomAtListIndex:_insertionIndex];
        [self.mathList insertAtom:atom atListIndex:_insertionIndex];
        return YES;
    }
    return NO;
}

- (void) insertText:(NSString*) str
{
    if(self.mathList.atoms.count == 0 && self.label.fontSize < 24) {
        [self updateFontSize:24.0];
    }
    BOOL isDefault = false;
    if ([self.delegate respondsToSelector:@selector(isDefaultKeyboard)]) {
        isDefault = [self.delegate isDefaultKeyboard];
    }
    if ([str isEqualToString:@"\n"]) {
        if ([self.delegate respondsToSelector:@selector(returnPressed:)]) {
            [self.delegate returnPressed:self];
        }
        return;
    }
    
    if (str.length == 0) {
        NSLog(@"Encounter key with 0 length string: %@", str);
        return;
    }
    
    unichar ch = [str characterAtIndex:0];
    MTMathAtom* atom;
    /*if (str.length > 1) {
     // Check if this is a supported command
     NSDictionary* commands = [MTMathListBuilder supportedCommands];
     MTMathAtom* factoryAtom = commands[str];
     atom = [factoryAtom copy]; // Make a copy here since atoms are mutable and we don't want to update the atoms in the map.
     }*/
    if (str.length > 1 && isDefault == false) {
        if ([str isEqualToString:@"Fraction"]) {
            atom = [MTMathAtomFactory placeholderFraction];
        } else if ([str isEqualToString:@"MixedNumberFraction"]) {
            atom = [MTMathAtomFactory placeholderMixedNumberFraction];
        } else {
            // If trig function, insert parens after
            if ([self isTrigFunction:str]) {
              if ([str isEqualToString:@"log"]) {
                [self handleLargeOperatorWithBoundaries:str];
              } else {
                [self handleTrig:str];
              }
            }
            else if ([str isEqualToString:@"lim"]) {
                [self handleLargeOperator:@"op" second:@"op" unicode: @"lim"];
            }
            else{
            // Check if this is a supported command
            NSArray* commands = [MTMathAtomFactory supportedLatexSymbolNames];
            // MTMathAtom* factoryAtom = commands[str];
            MTMathAtom* factoryAtom = [MTMathAtomFactory atomForLatexSymbolName:str];
            if(factoryAtom.type == kMTMathAtomLargeOperator){
                factoryAtom.isAtLayoutEnd = true;
            }
            atom = [factoryAtom copy]; // Make a copy here since atoms are mutable and we don't want to update the atoms in the map.
            }
        }
    } else if (str.length > 1 && isDefault == true) {
        /* This logic is handled when text is rendered from mic in native keyboard */
        for (int s = 0; s < str.length; s++) {
            
            MTMathAtom *atomFromVoice = [self atomForCharacter:[str characterAtIndex:s]];
            if (![self updatePlaceholderIfPresent:atomFromVoice]) {
                // If a placeholder wasn't updated then insert the new element.
                [self.mathList insertAtom:atomFromVoice atListIndex:_insertionIndex];
            }
            _insertionIndex = _insertionIndex.next;
        }
    }

    else {
        atom = [self atomForCharacter:ch];
        if(_insertionIndex.endIndex.subIndexType != kMTSubIndexTypeNone){
            atom.isChildAtom = true;
        }
    }
    
    if (_insertionIndex.subIndexType == kMTSubIndexTypeDenominator) {
        if (atom.type == kMTMathAtomRelation) {
            // pull the insertion index out
            _insertionIndex = [[_insertionIndex levelDown] next];
        }
    }
    
    if (atom && isDefault == true) {
        if (![self updatePlaceholderIfPresent:atom]) {
            // If a placeholder wasn't updated then insert the new element.
            [self.mathList insertAtom:atom atListIndex:_insertionIndex];
        }
        _insertionIndex = _insertionIndex.next;

    } else {
        if (ch == '^') {
            // Special ^ handling - adds an exponent
            if (isDefault == true) {
                return;
            } else {
                [self handleExponentButton:@"Superscript"];
            }
        } else if ([str isEqualToString:MTSymbolSquareRoot]) {
            [self handleRadical:NO];
        } else if ([str isEqualToString:MTSymbolCubeRoot]) {
            [self handleRadical:YES];
        } else if (ch == '_') {
            //[self handleSubscriptButton];
            [self handleExponentButton:@"Subscript"];
        } else if (ch == '/') {
            [self handleSlashButton];
        } else if ([str isEqualToString:@"()"]) {
            [self removePlaceholderIfPresent];
            [self insertParens];
        } else if (ch == '(' || ch == '[' || ch == '{') {
            [self handleLeftBoundaryOperator:[NSString stringWithCharacters:&ch length:1]];
        } else if (ch == ')' || ch == ']' || ch == '}') {
            [self handleRightBoundaryOperator:[NSString stringWithCharacters:&ch length:1]];
        }else if ([str isEqualToString:@"||"]) {
            [self removePlaceholderIfPresent];
            [self insertAbsValue];
        } else if ([str isEqualToString:@"hat"] || [str isEqualToString:@"overbar"] || [str isEqualToString:@"doubleoverbar"]) {
            [self removePlaceholderIfPresent];
            [self handleAccent: str];
        } else if ([str isEqualToString:@"Matrix"]) {
            [self handleMatrix: @"bmatrix"];
        } else if ([str isEqualToString:@"Determinant"]) {
            [self handleMatrix: @"vmatrix"];
        } else if ([str isEqualToString:@"IntegralWithLimits"]) {
            [self handleLargeOperator:@"op" second:@"op" unicode: @"\u222B"];
        } else if ([str isEqualToString:@"SummationWithLimits"]) {
            [self handleLargeOperator:@"op" second:@"op" unicode: @"\u2211"];
        } else if ([str isEqualToString:@"prime"] || [str isEqualToString:@"doubleprime"] || [str isEqualToString:@"tripleprime"]) {
            [self handlePrime: str];
        } else if ([str isEqualToString:@"OrderedPair"]){
            [self handlePair:str];
        } else if([str isEqualToString:@"SuperscriptAndSubscript"]) {
            [self handleExponentButton:@"SuperscriptAndSubscript"];
        } else if([str isEqualToString:@"SubscriptBeforeAndAfter"]) {
            [self handleExponentButton:@"SubscriptBeforeAndAfter"];
        } else if (atom) {
            if (![self updatePlaceholderIfPresent:atom]) {
                // If a placeholder wasn't updated then insert the new element.
                [self.mathList insertAtom:atom atListIndex:_insertionIndex];
            }
            if (atom.type == kMTMathAtomFraction) {
                // go to the numerator
                _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type: ((MTFraction *)atom).whole ? kMTSubIndexTypeWhole : kMTSubIndexTypeNumerator/*kMTSubIndexTypeNumerator*/];
            } else {
                _insertionIndex = _insertionIndex.next;
                
            }
        }

    }
    self.label.mathList = self.mathList;
    [self insertionPointChanged];
    
    if ([self.delegate respondsToSelector:@selector(textModified:)]) {
      [self.delegate textModified:self];
    }
    
//    if ([self.delegate respondsToSelector:@selector(textModified:withCaretView:)]) {
//        [self.delegate textModified:self withCaretView:_caretView];
//    }
}

// Return YES if string is a trig function, otherwise return NO
- (BOOL)isTrigFunction:(NSString *)string {
    NSArray *trigFunctions = @[@"sin", @"cos", @"tan", @"sec", @"csc", @"cot",@"sinh",@"cosh",@"tanh",@"sech",@"csch",@"coth",@"arcsin",@"arccos",@"arccot",@"arcsec",@"arccsc",@"arctan",@"ln",@"log"];
    
    for (NSString *trigFunction in trigFunctions) {
        if ([string isEqualToString:trigFunction]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)handleLargeOperatorWithBoundaries:(NSString*)nucleus{
    
//    MTLargeOperator* largeOpWithBoundaries = [[MTLargeOperator alloc] initWithValue:nucleus limits:false];
//    largeOpWithBoundaries.holder = [MTMathList new];
//    [largeOpWithBoundaries.holder addAtom:[MTMathAtomFactory placeholder]];
//    if (![self updatePlaceholderIfPresent:largeOpWithBoundaries]) {
//        // If the placeholder hasn't been updated then insert it.
//        [self.mathList insertAtom:largeOpWithBoundaries atListIndex:_insertionIndex];
//    }
//    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeLargeOpValueHolder];
    
    MTLargeOperator* largeOpWithBoundaries = [[MTLargeOperator alloc] initWithValue:nucleus limits:false];
    
//    if ([nucleus isEqualToString:@"log"]) {
//        largeOpWithBoundaries.subScript = [MTMathList new];
//        [largeOpWithBoundaries.subScript addAtom:[MTMathAtomFactory placeholder]];
//        if (![self updatePlaceholderIfPresent:largeOpWithBoundaries]) {
//            // If the placeholder hasn't been updated then insert it.
//            [self.mathList insertAtom:largeOpWithBoundaries atListIndex:_insertionIndex];
//        }
//        _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeSubscript];
//    }
//    else {
        [self.mathList insertAtom:largeOpWithBoundaries atListIndex:_insertionIndex];
        _insertionIndex = _insertionIndex.next;
//    }
}

- (void)handleTrig:(NSString*)function{
  MTLargeOperator* largeOpWithBoundaries = [[MTLargeOperator alloc] initWithValue:function limits:false];
  [self.mathList insertAtom:largeOpWithBoundaries atListIndex:_insertionIndex];
  _insertionIndex = _insertionIndex.next;
  MTInner *inner = [MTInner new];
  inner.leftBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:@"("];
  inner.rightBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:@")"];
  inner.innerList = [MTMathList new];
  [inner.innerList addAtom:[MTMathAtomFactory placeholder]];
  if (![self updatePlaceholderIfPresent:inner]) {
    [self.mathList insertAtom:inner atListIndex:_insertionIndex];
  }
  // update the insertion index
  _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeInner];
}

- (void) insertParens
{
    char ch = '(';
    MTMathAtom* atom = [self atomForCharacter:ch];
    [self.mathList insertAtom:atom atListIndex:_insertionIndex];
    _insertionIndex = _insertionIndex.next;
    ch = ')';
    atom = [self atomForCharacter:ch];
    [self.mathList insertAtom:atom atListIndex:_insertionIndex];
    // Don't go to the next insertion index, to start inserting before the close parens.
}

- (void) insertAbsValue
{
    // create the abs value
    MTAbsoluteValue *absValue = [MTAbsoluteValue new];
    absValue.open = absValue.close = @"|";
    absValue.absHolder = [MTMathList new];
    [absValue.absHolder addAtom:[MTMathAtomFactory placeholder]];
    // insert it
    if (![self updatePlaceholderIfPresent:absValue]) {
        [self.mathList insertAtom:absValue atListIndex:_insertionIndex];
    }
    // update the insertion index
    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeAbsValue];
}


- (void) deleteBackward
{
    // delete the last atom from the list
    MTMathListIndex* prevIndex = _insertionIndex.previous;
    if (self.hasText && prevIndex) {
        [self.mathList removeAtomAtListIndex:prevIndex];
        if (prevIndex.finalSubIndexType == kMTSubIndexTypeNucleus) {
            // it was in the nucleus and we removed it, get out of the nucleus and get in the nucleus of the previous one.
            MTMathListIndex* downIndex = prevIndex.levelDown;
            if (downIndex.previous) {
                prevIndex = [downIndex.previous levelUpWithSubIndex:[MTMathListIndex level0Index:1] type:kMTSubIndexTypeNucleus];
            } else {
                prevIndex = downIndex;
            }
        }
        _insertionIndex = prevIndex;
        if (_insertionIndex.isAtBeginningOfLine && _insertionIndex.subIndexType != kMTSubIndexTypeNone) {
            // We have deleted to the beginning of the line and it is not the outermost line
            MTMathAtom* atom = [self.mathList atomAtListIndex:_insertionIndex];
            if (!atom) {
                // add a placeholder if we deleted everything in the list
                atom = [MTMathAtomFactory placeholder];
                // mark the placeholder as selected since that is the current insertion point.
                atom.nucleus = MTSymbolBlackSquare;
                [self.mathList insertAtom:atom atListIndex:_insertionIndex];
            }
        }
        if(self.mathList.atoms.count == 0 && self.label.fontSize < 24.0){
            [self updateFontSize:24.0];
        }
        self.label.mathList = self.mathList;
        [self insertionPointChanged];
      
        if ([self.delegate respondsToSelector:@selector(textModified:)]) {
          [self.delegate textModified:self];
        }
        
//        if ([self.delegate respondsToSelector:@selector(textModified:withCaretView:)]) {
//            [self.delegate textModified:self withCaretView:_caretView];
//        }
    }
}

- (BOOL)hasText
{
    if (self.mathList.atoms.count > 0) {
        return YES;
    }
    return NO;
}

#pragma mark - UITextInputTraits

- (UITextAutocapitalizationType)autocapitalizationType
{
    return UITextAutocapitalizationTypeNone;
}

- (UITextAutocorrectionType)autocorrectionType
{
    return UITextAutocorrectionTypeNo;
}

- (UIReturnKeyType)returnKeyType
{
    return UIReturnKeyDefault;
}

- (UITextSpellCheckingType)spellCheckingType
{
    return UITextSpellCheckingTypeNo;
}

- (UIKeyboardType)keyboardType
{
    return UIKeyboardTypeASCIICapable;
}


#pragma mark - Hit Testing

- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    [self.label layoutIfNeeded];
    if (!self.label.displayList) {
        // no mathlist, so can't figure it out.
        return nil;
    }
    
    return [self.label.displayList closestIndexToPoint:[self convertPoint:point toView:self.label]];
}

- (CGPoint)caretRectForIndex:(MTMathListIndex *)index
{
    [self.label layoutIfNeeded];
    if (!self.label.displayList) {
        // no mathlist so we can't figure it out.
        return CGPointZero;
    }
    return [self.label.displayList caretPositionForIndex:index];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    BOOL inside = [super pointInside:point withEvent:event];
    if (inside) {
        return YES;
    }
    // check if a point is in the caret view.
    return [_caretView pointInside:[self convertPoint:point toView:_caretView] withEvent:event];
}

#pragma mark - Highlighting

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index
{
    [self.label layoutIfNeeded];
    if (!self.label.displayList) {
        // no mathlist so we can't figure it out.
        return;
    }
    // setup highlights before drawing the MTLine
    
    [self.label.displayList highlightCharacterAtIndex:index color:_highlightColor];
    
    [self.label setNeedsDisplay];
}

- (void) clearHighlights
{
    // relayout the displaylist to clear highlights
    [self.label setNeedsLayout];
}

#pragma mark - UITextInput

// These are blank just to get a UITextInput implementation, to fix the dictation button bug.
// Proposed fix from: http://stackoverflow.com/questions/20980898/work-around-for-dictation-custom-text-view-bug

@synthesize beginningOfDocument;
@synthesize endOfDocument;
@synthesize inputDelegate;
@synthesize markedTextRange;
@synthesize markedTextStyle;
@synthesize selectedTextRange;
@synthesize tokenizer;

- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction
{
    return UITextWritingDirectionLeftToRight;
}

- (CGRect)caretRectForPosition:(UITextPosition *)position
{
    return CGRectZero;
}

- (void)unmarkText
{
    
}

- (UITextRange *)characterRangeAtPoint:(CGPoint)point
{
    return nil;
}
- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction
{
    return nil;
}
- (UITextPosition *)closestPositionToPoint:(CGPoint)point
{
    return nil;
}
- (UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range
{
    return nil;
}
- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other
{
    return NSOrderedSame;
}
- (void)dictationRecognitionFailed
{
}
- (void)dictationRecordingDidEnd
{
}
- (CGRect)firstRectForRange:(UITextRange *)range
{
    return CGRectZero;
}

- (CGRect)frameForDictationResultPlaceholder:(id)placeholder
{
    return CGRectZero;
}

- (void)insertDictationResult:(NSArray *)dictationResult
{
    NSString *voiceText = [[[dictationResult firstObject] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self insertText:voiceText];
}

- (id)insertDictationResultPlaceholder
{
    return nil;
}

- (NSInteger)offsetFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition
{
    return 0;
}
- (UITextPosition *)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset
{
    return nil;
}
- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset
{
    return nil;
}

- (UITextPosition *)positionWithinRange:(UITextRange *)range farthestInDirection:(UITextLayoutDirection)direction
{
    return nil;
}
- (void)removeDictationResultPlaceholder:(id)placeholder willInsertResult:(BOOL)willInsertResult
{
}
- (void)replaceRange:(UITextRange *)range withText:(NSString *)text
{
}
- (NSArray *)selectionRectsForRange:(UITextRange *)range
{
    return nil;
}
- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection forRange:(UITextRange *)range
{
}
- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange
{
}

- (NSString *)textInRange:(UITextRange *)range
{
    return nil;
}
- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition
{
    return nil;
}


#pragma mark - Caret View

- (void)showOrHideCaretView:(BOOL)showOrHide {
    _caretView.caretColor = (showOrHide == true) ? [UIColor clearColor] : [UIColor colorWithWhite:0.1 alpha:1.0];
    _caretView.hidden = showOrHide;
}

- (void)updateInsertionIndexToCaptureEquationImage{
    if(self.mathList.atoms.count > 0) {
        _insertionIndex = [MTMathListIndex indexAtLocation:self.mathList.atoms.count withSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeNone];
    }
}

#pragma mark - Next / Previous

- (void)levelDownToInterAtoms:(MTMathAtom*)interAtom {
    
    MTMathListIndex *endIndex = _insertionIndex.endIndex;
    MTMathAtom *atom = [self.mathList retrieveAtomAtListIndex:_insertionIndex];
    switch (atom.type) {
            
        case kMTMathAtomAccent:{
            [self levelDownAtomsForAccent:(MTAccent*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomAbsoluteValue:{
            [self levelDownAtomsForAbsoluteValue:(MTAbsoluteValue*)atom forIndex:endIndex];
            break;
        }
            
        case kMTMathAtomFraction: {
            [self levelDownAtomsForFraction:(MTFraction*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomOrderedPair:{
            [self levelDownAtomsForOrderedPair:(MTOrderedPair*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomBinomialMatrix: {
            [self levelDownAtomsForBinomialMatrix:(MTBinomialMatrix*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomRadical: {
            [self levelDownAtomsForRadical:(MTRadical*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomExponentBase:{
            [self levelDownAtomsForExponents:(MTExponent*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomLargeOperator: {
            [self levelDownAtomsForLargeOperator:(MTLargeOperator*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomInner: {
            [self levelDownAtomsForInner:(MTInner*)atom forIndex:endIndex];
            break;
        }
        default:
            if(_insertionIndex.atomIndex < self.mathList.atoms.count){
                atom = [[self.mathList atoms] objectAtIndex:_insertionIndex.atomIndex];
            }
            if([self isInterAtomHasLayout:atom] && atom.isAtLayoutEnd == false && ![self isTrigFunction:atom.nucleus]){
                [self fetchChildAtomsAndUpdateInsertionIndex:atom isNextNavigation:true];
                return;
            }
            _insertionIndex = _insertionIndex.next;
            break;
    }
}


- (void)levelUpToInterAtoms:(MTMathAtom*)interAtom {
    
    MTMathListIndex *endIndex = _insertionIndex.endIndex;
    MTMathAtom *atom = [self.mathList retrieveAtomAtListIndex:_insertionIndex];
    switch (atom.type) {
            
        case kMTMathAtomAccent:{
            [self levelUpAtomsForAccent:(MTAccent*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomAbsoluteValue:{
            [self levelUpAtomsForAbsoluteValue:(MTAbsoluteValue*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomFraction: {
            [self levelUpAtomsForFraction:(MTFraction*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomOrderedPair:{
            [self levelUpAtomsForOrderedPair:(MTOrderedPair*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomBinomialMatrix: {
            [self levelUpAtomsForBinomialMatrix:(MTBinomialMatrix*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomRadical: {
            [self levelUpAtomsForRadical:(MTRadical*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomExponentBase: {
            [self levelUpAtomsForExponents:(MTExponent*)atom forIndex:endIndex];
            break;
        }
        case kMTMathAtomLargeOperator: {
            [self levelUpAtomsForLargeOperator:(MTLargeOperator*)atom forIndex:(MTMathListIndex*)endIndex];
            break;
        }
        case kMTMathAtomInner: {
            [self levelUpAtomsForInner:(MTInner*)atom forIndex:endIndex];
            break;
        }
        default:
        {
            if(_insertionIndex.endIndex.subIndexType == kMTSubIndexTypeNone){
                if(_insertionIndex.atomIndex > 0){
                    _insertionIndex.atomIndex = _insertionIndex.atomIndex-1;
                    if( _insertionIndex.atomIndex < self.mathList.atoms.count){
                        atom = [[self.mathList atoms] objectAtIndex: _insertionIndex.atomIndex];
                    }
                    if([self isInterAtomHasLayout:atom] && atom.isAtLayoutEnd == false){
                        [self fetchChildAtomsAndUpdateInsertionIndex:atom isNextNavigation:false];
                        return;
                    }
                }
            }
            break;
         }
    }
}


- (void)fetchChildAtomsAndUpdateInsertionIndex:(MTMathAtom*)atom isNextNavigation:(BOOL)isNext {
    
    MTMathListIndex *finalIndex = _insertionIndex.endIndex;
    if (finalIndex.subIndexType == kMTSubIndexTypeNone) {
        _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:[self getSubIndexTypeForAtom:atom isNextNavigation:isNext]];
        if(isNext == false){
            [self updateInterElementAtomsCount:atom forIndex:_insertionIndex.endIndex];
            return;
        }
        [self fetchChildAtomsAndUpdateInsertionIndex:atom isNextNavigation:isNext];
        return;
    }
    MTMathAtom *innerAtom = nil;
    switch (atom.type) {
        case kMTMathAtomAccent:{
            MTAccent *accent = (MTAccent*)atom;
            NSArray *childAtoms = accent.innerList.atoms;
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
        case kMTMathAtomAbsoluteValue:{
            MTAbsoluteValue *absValue = (MTAbsoluteValue*)atom;
            NSArray *childAtoms = absValue.absHolder.atoms;
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
        case kMTMathAtomFraction:{
            MTFraction *fraction = (MTFraction*)atom;
            NSArray *childAtoms = nil;
            if (finalIndex.subIndexType == kMTSubIndexTypeWhole){
                childAtoms = fraction.whole.atoms;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeNumerator){
                childAtoms =  fraction.numerator.atoms;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeDenominator){
                childAtoms =  fraction.denominator.atoms;
            }
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
        case kMTMathAtomOrderedPair:{
            MTOrderedPair *orderedPair = (MTOrderedPair*)atom;
            NSArray *childAtoms = (finalIndex.subIndexType == kMTSubIndexTypeLeftOperand)?orderedPair.leftOperand.atoms:orderedPair.rightOperand.atoms;
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
        case kMTMathAtomBinomialMatrix:{
            MTBinomialMatrix *matrix = (MTBinomialMatrix*)atom;
            NSArray *childAtoms = nil;
            if (finalIndex.subIndexType == kMTSubIndexTypeRow0Col0){
                childAtoms = matrix.row0Col0.atoms;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeRow0Col1){
                childAtoms =  matrix.row0Col1.atoms;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeRow1Col0){
                childAtoms =  matrix.row1Col0.atoms;
            } else {
                childAtoms = matrix.row1Col1.atoms;
            }
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
        case kMTMathAtomRadical:{
            MTRadical *radical = (MTRadical*)atom;
            NSArray *childAtoms = (finalIndex.subIndexType == kMTSubIndexTypeDegree)?radical.degree.atoms:radical.radicand.atoms;
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
        case kMTMathAtomExponentBase:{
            MTExponent *exponent = (MTExponent*)atom;
            NSArray *childAtoms = nil;
            if (finalIndex.subIndexType == kMTSubIndexTypeExponent){
                childAtoms = exponent.exponent.atoms;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeExpSuperscript){
                childAtoms =  exponent.expSuperScript.atoms;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeExpSubscript){
                childAtoms =  exponent.expSubScript.atoms;
            } else {
                childAtoms = exponent.prefixedSubScript.atoms;
            }
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
        case kMTMathAtomLargeOperator:{
            MTLargeOperator *largeOp = (MTLargeOperator*)atom;
            NSArray *childAtoms = nil;
            if (finalIndex.subIndexType == kMTSubIndexTypeSuperscript){
                childAtoms = largeOp.superScript.atoms;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeSubscript){
                childAtoms =  largeOp.subScript.atoms;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeLargeOpValueHolder){
                childAtoms =  largeOp.holder.atoms;
            }
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
        case kMTMathAtomInner:{
            MTInner *innerValue = (MTInner*)atom;
            NSArray *childAtoms = innerValue.innerList.atoms;
            innerAtom = (isNext)?[childAtoms firstObject]:[childAtoms lastObject];
            break;
        }
            
        default:{
//            _insertionIndex = [MTMathListIndex indexAtLocation:_insertionIndex.atomIndex withSubIndex:[MTMathListIndex level0Index:0] type:kMTSubIndexTypeNone];
            break;
        }
    }
    if([self isInterAtomHasLayout:innerAtom]) {
        _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:[self getSubIndexTypeForAtom:innerAtom isNextNavigation:isNext]];
        if(isNext == false){
            [self updateInterElementAtomsCount:innerAtom forIndex:_insertionIndex.endIndex];
        }
        [self fetchChildAtomsAndUpdateInsertionIndex: innerAtom isNextNavigation:isNext];
        return;
    }
}

- (void)updateInterElementAtomsCount:(MTMathAtom*)atom forIndex:(MTMathListIndex*)finalIndex {
    switch (atom.type) {
            
        case kMTMathAtomAccent:{
            MTAccent *accent = (MTAccent*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeOverbar){
                finalIndex.subIndex.atomIndex = accent.innerList.atoms.count;
            }
            break;
        }
        case kMTMathAtomAbsoluteValue:{
            MTAbsoluteValue *absValue = (MTAbsoluteValue*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeAbsValue){
                finalIndex.subIndex.atomIndex = absValue.absHolder.atoms.count;
            }
            break;
        }
        case kMTMathAtomInner:{
            MTInner *innerValue = (MTInner*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeInner){
                finalIndex.subIndex.atomIndex = innerValue.innerList.atoms.count;
            }
            break;
        }
        case kMTMathAtomFraction:{
            MTFraction *fraction = (MTFraction*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeDenominator){
                finalIndex.subIndex.atomIndex = fraction.denominator.atoms.count;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeNumerator){
                finalIndex.subIndex.atomIndex = fraction.numerator.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeWhole){
                finalIndex.subIndex.atomIndex = fraction.whole.atoms.count;
            }
            break;
        }
        case kMTMathAtomOrderedPair:{
            MTOrderedPair *pair = (MTOrderedPair*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeRightOperand){
                    finalIndex.subIndex.atomIndex = pair.rightOperand.atoms.count;
            } else if(finalIndex.subIndexType == kMTSubIndexTypeLeftOperand){
                    finalIndex.subIndex.atomIndex = pair.leftOperand.atoms.count;
            }
            break;
        }
        case kMTMathAtomBinomialMatrix:{
            MTBinomialMatrix *matrix = (MTBinomialMatrix*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeRow1Col1){
                finalIndex.subIndex.atomIndex = matrix.row1Col1.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeRow1Col0){
                finalIndex.subIndex.atomIndex = matrix.row1Col0.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeRow0Col1){
                finalIndex.subIndex.atomIndex = matrix.row0Col1.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeRow0Col0){
                finalIndex.subIndex.atomIndex = matrix.row0Col0.atoms.count;
            }
            break;
        }
        case kMTMathAtomRadical:{
            MTRadical *radical = (MTRadical*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeDegree){
                finalIndex.subIndex.atomIndex = radical.degree.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeRadicand){
                finalIndex.subIndex.atomIndex = radical.radicand.atoms.count;
            }
            break;
        }
        case kMTMathAtomExponentBase:{
            MTExponent *exponent = (MTExponent*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeExponent){
                finalIndex.subIndex.atomIndex = exponent.exponent.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeExpSuperscript){
                finalIndex.subIndex.atomIndex = exponent.expSuperScript.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeExpSubscript){
                finalIndex.subIndex.atomIndex = exponent.expSubScript.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeExpBeforeSubscript){
                finalIndex.subIndex.atomIndex = exponent.prefixedSubScript.atoms.count;
            }
            break;
            
        }
        case kMTMathAtomLargeOperator: {
            MTLargeOperator *largeOp = (MTLargeOperator*)atom;
            if(finalIndex.subIndexType == kMTSubIndexTypeSuperscript){
                finalIndex.subIndex.atomIndex = largeOp.superScript.atoms.count;
            }
            else if(finalIndex.subIndexType == kMTSubIndexTypeSubscript){
                finalIndex.subIndex.atomIndex = largeOp.subScript.atoms.count;
            }else if(finalIndex.subIndexType == kMTSubIndexTypeLargeOpValueHolder){
                finalIndex.subIndex.atomIndex = largeOp.holder.atoms.count;
            }
            break;
        }
        default:{
            break;
        }
    }
    
}

- (MTMathListSubIndexType)getSubIndexTypeForAtom:(MTMathAtom*)atom isNextNavigation:(BOOL)isNext {
    
    MTMathListSubIndexType subIndexType = kMTSubIndexTypeNone;
    if (atom.type == kMTMathAtomFraction) {
        if (isNext){
            MTFraction *fraction = (MTFraction*)atom;
            if(fraction.whole){
                subIndexType = kMTSubIndexTypeWhole;
            }else{
                subIndexType = kMTSubIndexTypeNumerator;
            }
        }else {
            subIndexType = kMTSubIndexTypeDenominator;
        }
    } else if (atom.type == kMTMathAtomOrderedPair) {
        if (isNext){
            subIndexType = kMTSubIndexTypeLeftOperand;
        }else {
            subIndexType = kMTSubIndexTypeRightOperand;
        }
    }else if (atom.type == kMTMathAtomBinomialMatrix) {
        if (isNext) {
            subIndexType = kMTSubIndexTypeRow0Col0;
        } else {
            subIndexType = kMTSubIndexTypeRow1Col1;
        }
    } else if (atom.type == kMTMathAtomRadical) {
        MTRadical *radical = (MTRadical*)atom;
        if (isNext) {
            subIndexType = (radical.degree != nil)?kMTSubIndexTypeDegree:kMTSubIndexTypeRadicand;
        } else {
            subIndexType = kMTSubIndexTypeRadicand;
        }
    } else if (atom.type == kMTMathAtomAbsoluteValue) {
        subIndexType = kMTSubIndexTypeAbsValue;
    }else if (atom.type == kMTMathAtomAccent) {
        subIndexType = kMTSubIndexTypeOverbar;
    }else if (atom.type == kMTMathAtomExponentBase) {
        MTExponent *exponent = (MTExponent*)atom;
        if(exponent.isSuperScriptTypePrime == true){
            subIndexType = kMTSubIndexTypeExponent;
        } else {
            if (isNext) {
                subIndexType = (exponent.prefixedSubScript != nil)?kMTSubIndexTypeExpBeforeSubscript:kMTSubIndexTypeExponent;
            } else {
                if(exponent.expSubScript){
                    subIndexType = kMTSubIndexTypeExpSubscript;
                } else if (exponent.expSuperScript && !exponent.expSubScript) {
                    subIndexType = kMTSubIndexTypeExpSuperscript;
                }
            }
        }
    } else if(atom.type == kMTMathAtomLargeOperator){
        MTLargeOperator *largeOp = (MTLargeOperator*)atom;
        if(isNext){
            if(largeOp.holder){
                subIndexType = kMTSubIndexTypeLargeOpValueHolder;
            } else if(largeOp.superScript){
                subIndexType = kMTSubIndexTypeSuperscript;
            } else {
                subIndexType = kMTSubIndexTypeLargeOp;
            }
        }else {
            if(largeOp.holder){
                subIndexType = kMTSubIndexTypeLargeOpValueHolder;
            } else if(largeOp.subScript){
                subIndexType = kMTSubIndexTypeSubscript;
            }else {
                subIndexType = kMTSubIndexTypeLargeOp;
            }
        }
    }
    else if (atom.type == kMTMathAtomInner) {
        subIndexType = kMTSubIndexTypeInner;
    }
    return subIndexType;
}

- (void)navigateWithinInterElements:(MTMathAtom*)parentAtom childAtoms:(NSArray*)childAtoms forIndex:(MTMathListIndex*)parentInsertionIndex isNextNavigation:(BOOL)isNext {
    
    if(isNext) {
        if(parentInsertionIndex.subIndex.atomIndex < childAtoms.count){
            MTMathAtom *innerAtom = [childAtoms objectAtIndex:parentInsertionIndex.subIndex.atomIndex];
            if([self isInterAtomHasLayout:innerAtom] && innerAtom.isAtLayoutEnd == false){
                    _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:[self getSubIndexTypeForAtom:innerAtom isNextNavigation:true]];
                    [self fetchChildAtomsAndUpdateInsertionIndex:innerAtom isNextNavigation:true];
                    return;
            }
            else {
                parentInsertionIndex.subIndex.atomIndex = parentInsertionIndex.subIndex.atomIndex+1;
                return;
            }
        }
    }
    else {
        if(parentInsertionIndex.subIndex.atomIndex > 0){
            if(parentInsertionIndex.subIndex.atomIndex <= childAtoms.count){
                MTMathAtom *innerAtom = [childAtoms objectAtIndex:parentInsertionIndex.subIndex.atomIndex-1];
                if([self isInterAtomHasLayout:innerAtom] && innerAtom.isAtLayoutEnd == false){
                        _insertionIndex = [_insertionIndex levelUpWithSubIndex:[MTMathListIndex level0Index:0] type:[self getSubIndexTypeForAtom:innerAtom isNextNavigation:false]];
                        _insertionIndex.endIndex.atomIndex =  _insertionIndex.endIndex.atomIndex-1;
                        [self updateInterElementAtomsCount:innerAtom forIndex:_insertionIndex.endIndex];
                        return;
                }
                    else {
                        parentInsertionIndex.subIndex.atomIndex = parentInsertionIndex.subIndex.atomIndex-1;
                        return;
                    }
            }
        }
    }
}

- (BOOL)isInterAtomHasLayout:(MTMathAtom*)interAtom {
    
    if (([interAtom isKindOfClass:[MTOrderedPair class]]) || ([interAtom isKindOfClass:[MTFraction class]]) || ([interAtom isKindOfClass:[MTBinomialMatrix class]]) || ([interAtom isKindOfClass:[MTRadical class]]) || ([interAtom isKindOfClass:[MTAbsoluteValue class]]) || ([interAtom isKindOfClass:[MTExponent class]]) || ([interAtom isKindOfClass:[MTLargeOperator class]]) || ([interAtom isKindOfClass:[MTAccent class]]) || ([interAtom isKindOfClass:[MTInner class]])) {
        
        return true;
    }
    return false;
}

- (BOOL)isPlaceholderAtom:(MTMathAtom*)interAtom {
    if (interAtom.type == kMTMathAtomPlaceholder) {
        return true;
    }
    return false;
}

- (BOOL)canLevelDownForPreviousNavigation{
    if(_insertionIndex.atomIndex == 0 && _insertionIndex.subIndexType == kMTSubIndexTypeNone){
        return false;
    }
    return true;
}
    
- (BOOL)isCursorPlacedAfterLayoutEnd:(NSArray*)childAtoms:(BOOL)isNextNavigation {

    if ([self isPlaceholderAtom:[childAtoms firstObject]]) {
        return true;
    }
    if(isNextNavigation) {
        if (_insertionIndex.endIndex.subIndex.atomIndex == childAtoms.count){
            _insertionIndex.endIndex.subIndex.atomIndex = 0;
            return true;
        }
    } else {
        if (_insertionIndex.endIndex.subIndex.atomIndex == 0){
            return true;
        }
    }
   
    return false;
}


- (void)loadNextAtom {
    if (self.mathList == nil || self.mathList.atoms == nil || self.mathList.atoms.count == 0) {
        if ([self.delegate respondsToSelector:@selector(cursorReachedRight)]) {
            [self.delegate cursorReachedRight];
        }
        return;
    }
    MTMathAtom* atom = nil;
    if(_insertionIndex.atomIndex < self.mathList.atoms.count){
        atom = [[self.mathList atoms] objectAtIndex:_insertionIndex.atomIndex];
    }
    else {
        if ([self.delegate respondsToSelector:@selector(cursorReachedRight)]) {
            [self.delegate cursorReachedRight];
        }
        return;
    }
    [self levelDownToInterAtoms:atom];
    [self insertionPointChanged];
}

- (void)loadPreviousAtom {
    if ([self canLevelDownForPreviousNavigation] == false){
        if ([self.delegate respondsToSelector:@selector(cursorReachedLeft)]) {
            [self.delegate cursorReachedLeft];
        }
        return;
    }
    
    MTMathAtom* atom = nil;
    
    if(_insertionIndex.atomIndex < self.mathList.atoms.count){
        atom = [[self.mathList atoms] objectAtIndex:_insertionIndex.atomIndex];
    }
    [self levelUpToInterAtoms:atom];
    [self insertionPointChanged];
    
}

//- (MTDisplay*)getCurrentDisplay {
//    MTMathListIndex *parentIndex = _insertionIndex.getParentIndex;
//    MTMathAtom *atom = [self.mathList retrieveAtomAtListIndex:(parentIndex == nil)?_insertionIndex:parentIndex];
//    MTDisplay *subDisplay = nil;
//    if([self isInterAtomHasLayout:atom]) {
//        subDisplay = [self.label.displayList retrieveDisplayForIndex:(parentIndex == nil)?_insertionIndex:parentIndex];
//    }
//    return subDisplay;
//}

- (CGFloat)getCurrentDisplayWidth {
    MTMathListIndex *parentIndex = _insertionIndex.getParentIndex;
    MTMathAtom *atom = [self.mathList retrieveAtomAtListIndex:(parentIndex == nil)?_insertionIndex:parentIndex];
    MTDisplay *subDisplay = nil;
    CGFloat totalWidth = 0.0;
    if([self isInterAtomHasLayout:atom]) {
        subDisplay = [self.label.displayList retrieveDisplayForIndex:(parentIndex == nil)?_insertionIndex:parentIndex];
        totalWidth = subDisplay.position.x + subDisplay.width;
    }
    else {
        MTMathAtom *prevAtom = [self.mathList atomAtListIndex:_insertionIndex.previous];
        if(prevAtom) {
            if (prevAtom.type == kMTMathAtomRelation || prevAtom.type == kMTMathAtomBinaryOperator){
                subDisplay = [self.label.displayList.subDisplays lastObject];
                totalWidth = subDisplay.position.x + subDisplay.width;
            } else {
                NSInteger atomPos = [self.mathList.atoms indexOfObject:prevAtom];
                for (NSInteger i = atomPos; i >= 0; i--) {
                    MTMathAtom *prevAtom = [self.mathList.atoms objectAtIndex:i];
                    if ([prevAtom.nucleus isEqualToString:@" "] || prevAtom.type == kMTMathAtomRelation || prevAtom.type == kMTMathAtomBinaryOperator) {
                        break;
                    } else {
                        totalWidth += [[self.label.displayList.subDisplays objectAtIndex:i] width];
                    }
                }
            }
        }
    }
    return totalWidth;
}


#pragma mark Fraction and Mixed Fraction

- (void)levelDownAtomsForFraction:(MTFraction*)fraction forIndex:(MTMathListIndex*)endIndex {
    
    if(endIndex.subIndexType == kMTSubIndexTypeWhole){
        if([self isCursorPlacedAfterLayoutEnd:fraction.whole.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeNumerator isEndAtom:[self isCursorPlacedAfterLayoutEnd:fraction.numerator.atoms:true]];
        }
        else {
            [self navigateWithinInterElements:fraction childAtoms:fraction.whole.atoms forIndex:endIndex isNextNavigation:true];
            return;
        };
        
    }
    else if(endIndex.subIndexType == kMTSubIndexTypeNumerator){
        if([self isCursorPlacedAfterLayoutEnd:fraction.numerator.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeDenominator isEndAtom:[self isCursorPlacedAfterLayoutEnd:fraction.denominator.atoms:true]];
        }
        else {
            [self navigateWithinInterElements:fraction childAtoms:fraction.numerator.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeDenominator){
        if([self isCursorPlacedAfterLayoutEnd:fraction.denominator.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(fraction.isAtLayoutEnd == false){
                fraction.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            fraction.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:fraction childAtoms:fraction.denominator.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
}


- (void)levelUpAtomsForFraction:(MTFraction*)fraction forIndex:(MTMathListIndex*)endIndex {
    if(endIndex.subIndexType == kMTSubIndexTypeWhole){
        if([self isCursorPlacedAfterLayoutEnd:fraction.whole.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:fraction childAtoms:fraction.whole.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if(endIndex.subIndexType == kMTSubIndexTypeNumerator){
        if([self isCursorPlacedAfterLayoutEnd:fraction.numerator.atoms :false]) {
            if(fraction.whole){
                if([self isCursorPlacedAfterLayoutEnd:fraction.whole.atoms :false]) {
                    _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeWhole isEndAtom:[self isCursorPlacedAfterLayoutEnd:fraction.whole.atoms:false]];
                    [self updateInterElementAtomsCount:fraction forIndex:_insertionIndex.endIndex];
                }
                else {
                    [self navigateWithinInterElements:fraction childAtoms:fraction.whole.atoms forIndex:endIndex isNextNavigation:false];
                    return;
                }
            }
            else {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
                _insertionIndex = _insertionIndex.levelDownToNextLayout;
            }
        }
        else {
            [self navigateWithinInterElements:fraction childAtoms:fraction.numerator.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeDenominator){
        if([self isCursorPlacedAfterLayoutEnd:fraction.denominator.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeNumerator isEndAtom:[self isCursorPlacedAfterLayoutEnd:fraction.numerator.atoms:false]];
            [self updateInterElementAtomsCount:fraction forIndex:_insertionIndex.endIndex];
        }
        else {
            [self navigateWithinInterElements:fraction childAtoms:fraction.denominator.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
}

#pragma mark Ordered Pair

- (void)levelDownAtomsForOrderedPair:(MTOrderedPair*)orderedPair forIndex:(MTMathListIndex*)endIndex {

    if(endIndex.subIndexType == kMTSubIndexTypeLeftOperand){
        if([self isCursorPlacedAfterLayoutEnd:orderedPair.leftOperand.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeRightOperand isEndAtom:[self isCursorPlacedAfterLayoutEnd:orderedPair.rightOperand.atoms:true]];
        }
        else {
            [self navigateWithinInterElements:orderedPair childAtoms:orderedPair.leftOperand.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeRightOperand){
        if([self isCursorPlacedAfterLayoutEnd:orderedPair.rightOperand.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(orderedPair.isAtLayoutEnd == false){
                orderedPair.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            orderedPair.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:orderedPair childAtoms:orderedPair.rightOperand.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
}

- (void)levelUpAtomsForOrderedPair:(MTOrderedPair*)orderedPair forIndex:(MTMathListIndex*)endIndex {
    
    if(endIndex.subIndexType == kMTSubIndexTypeLeftOperand){
        if([self isCursorPlacedAfterLayoutEnd:orderedPair.leftOperand.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:orderedPair childAtoms:orderedPair.leftOperand.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeRightOperand){
        if([self isCursorPlacedAfterLayoutEnd:orderedPair.rightOperand.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeLeftOperand isEndAtom:[self isCursorPlacedAfterLayoutEnd:orderedPair.leftOperand.atoms:false]];
            [self updateInterElementAtomsCount:orderedPair forIndex:_insertionIndex.endIndex];
        }
        else {
            [self navigateWithinInterElements:orderedPair childAtoms:orderedPair.rightOperand.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
}

#pragma mark Binomial Matrix


- (void)levelDownAtomsForBinomialMatrix:(MTBinomialMatrix*)matrix forIndex:(MTMathListIndex*)endIndex {
    if(endIndex.subIndexType == kMTSubIndexTypeRow0Col0){
        if([self isCursorPlacedAfterLayoutEnd:matrix.row0Col0.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeRow0Col1 isEndAtom:[self isCursorPlacedAfterLayoutEnd:matrix.row0Col0.atoms:true]];
        }
        else {
            [self navigateWithinInterElements:matrix childAtoms:matrix.row0Col0.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
    else if(endIndex.subIndexType == kMTSubIndexTypeRow0Col1){
        if([self isCursorPlacedAfterLayoutEnd:matrix.row0Col1.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeRow1Col0 isEndAtom:[self isCursorPlacedAfterLayoutEnd:matrix.row0Col1.atoms:true]];
        }
        else {
            [self navigateWithinInterElements:matrix childAtoms:matrix.row0Col1.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
    else if(endIndex.subIndexType == kMTSubIndexTypeRow1Col0){
        if([self isCursorPlacedAfterLayoutEnd:matrix.row1Col0.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeRow1Col1 isEndAtom:[self isCursorPlacedAfterLayoutEnd:matrix.row1Col0.atoms:true]];
        }
        else {
            [self navigateWithinInterElements:matrix childAtoms:matrix.row1Col0.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeRow1Col1){
        if([self isCursorPlacedAfterLayoutEnd:matrix.row1Col1.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(matrix.isAtLayoutEnd == false){
                matrix.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            matrix.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:matrix childAtoms:matrix.row1Col1.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
}

- (void)levelUpAtomsForBinomialMatrix:(MTBinomialMatrix*)matrix forIndex:(MTMathListIndex*)endIndex  {
    if(endIndex.subIndexType == kMTSubIndexTypeRow0Col0){
        if([self isCursorPlacedAfterLayoutEnd:matrix.row0Col0.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:matrix childAtoms:matrix.row0Col0.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeRow0Col1){
        if([self isCursorPlacedAfterLayoutEnd:matrix.row0Col1.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeRow0Col0 isEndAtom:[self isCursorPlacedAfterLayoutEnd:matrix.row0Col0.atoms:false]];
            [self updateInterElementAtomsCount:matrix forIndex:_insertionIndex.endIndex];
        }
        else {
            [self navigateWithinInterElements:matrix childAtoms:matrix.row0Col1.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeRow1Col0){
        if([self isCursorPlacedAfterLayoutEnd:matrix.row1Col0.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeRow0Col1 isEndAtom:[self isCursorPlacedAfterLayoutEnd:matrix.row0Col1.atoms:false]];
            [self updateInterElementAtomsCount:matrix forIndex:_insertionIndex.endIndex];
        }
        else {
            [self navigateWithinInterElements:matrix childAtoms:matrix.row1Col0.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeRow1Col1){
        if([self isCursorPlacedAfterLayoutEnd:matrix.row1Col1.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeRow1Col0 isEndAtom:[self isCursorPlacedAfterLayoutEnd:matrix.row1Col0.atoms:false]];
            [self updateInterElementAtomsCount:matrix forIndex:_insertionIndex.endIndex];
        }
        else {
            [self navigateWithinInterElements:matrix childAtoms:matrix.row1Col1.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
}

#pragma mark Exponent

- (void)levelDownAtomsForExponents:(MTExponent*)exponent forIndex:(MTMathListIndex*)endIndex {
    
    if (endIndex.subIndexType == kMTSubIndexTypeExponent && exponent.isSuperScriptTypePrime == true){
        if([self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(exponent.isAtLayoutEnd == false){
                exponent.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            exponent.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:exponent childAtoms:exponent.exponent.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
    else {
        if((endIndex.subIndexType == kMTSubIndexTypeExpBeforeSubscript)){
            if([self isCursorPlacedAfterLayoutEnd:exponent.prefixedSubScript.atoms :true]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeExponent isEndAtom:[self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms:true]];
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.prefixedSubScript.atoms forIndex:endIndex isNextNavigation:true];
                return;
            }
        }
        else if((endIndex.subIndexType == kMTSubIndexTypeExponent && !exponent.expSubScript && exponent.expSuperScript) || (endIndex.subIndexType == kMTSubIndexTypeExponent && exponent.expSubScript && exponent.expSuperScript)){
            if([self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms :true]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeExpSuperscript isEndAtom:[self isCursorPlacedAfterLayoutEnd:exponent.expSuperScript.atoms:true]];
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.exponent.atoms forIndex:endIndex isNextNavigation:true];
                return;
            }
        }
        else if((endIndex.subIndexType == kMTSubIndexTypeExponent && exponent.expSubScript && !exponent.expSuperScript)){
            if([self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms :true]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeExpSubscript isEndAtom:[self isCursorPlacedAfterLayoutEnd:exponent.expSubScript.atoms:true]];
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.exponent.atoms forIndex:endIndex isNextNavigation:true];
                return;
            }
        }
        else if(endIndex.subIndexType == kMTSubIndexTypeExpSuperscript && exponent.expSubScript){
            if([self isCursorPlacedAfterLayoutEnd:exponent.expSuperScript.atoms :true]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeExpSubscript isEndAtom:[self isCursorPlacedAfterLayoutEnd:exponent.expSubScript.atoms:true]];
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.expSuperScript.atoms forIndex:endIndex isNextNavigation:true];
                return;
            }
        }
        else if ((endIndex.subIndexType == kMTSubIndexTypeExpSuperscript && !exponent.expSubScript))
        {
            if([self isCursorPlacedAfterLayoutEnd:exponent.expSuperScript.atoms :true]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
                _insertionIndex = _insertionIndex.levelDownToNextLayout;
                if(exponent.isAtLayoutEnd == false){
                    exponent.isAtLayoutEnd = true;
                }
                [self levelDownToInterAtoms:nil];
                exponent.isAtLayoutEnd = false;
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.expSuperScript.atoms forIndex:endIndex isNextNavigation:true];
                return;
            }
        }
        else if (endIndex.subIndexType == kMTSubIndexTypeExpSubscript)
        {
            if([self isCursorPlacedAfterLayoutEnd:exponent.expSubScript.atoms :true]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
                _insertionIndex = _insertionIndex.levelDownToNextLayout;
                if(exponent.isAtLayoutEnd == false){
                    exponent.isAtLayoutEnd = true;
                }
                [self levelDownToInterAtoms:nil];
                exponent.isAtLayoutEnd = false;
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.expSubScript.atoms forIndex:endIndex isNextNavigation:true];
                return;
            }
        }
    }
}
    
- (void)levelUpAtomsForExponents:(MTExponent*)exponent forIndex:(MTMathListIndex*)endIndex {
    
    if (endIndex.subIndexType == kMTSubIndexTypeExponent && exponent.isSuperScriptTypePrime == true){
        if([self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:exponent childAtoms:exponent.exponent.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    } else {
        if(endIndex.subIndexType == kMTSubIndexTypeExpSuperscript){
            if([self isCursorPlacedAfterLayoutEnd:exponent.expSuperScript.atoms :false]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeExponent isEndAtom:[self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms:false]];
                [self updateInterElementAtomsCount:exponent forIndex:_insertionIndex.endIndex];
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.expSuperScript.atoms forIndex:endIndex isNextNavigation:false];
                return;
            }
        }
        else if(endIndex.subIndexType == kMTSubIndexTypeExpSubscript && exponent.expSuperScript){
            if([self isCursorPlacedAfterLayoutEnd:exponent.expSubScript.atoms :false]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeExpSuperscript isEndAtom:[self isCursorPlacedAfterLayoutEnd:exponent.expSuperScript.atoms:false]];
                [self updateInterElementAtomsCount:exponent forIndex:_insertionIndex.endIndex];
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.expSubScript.atoms forIndex:endIndex isNextNavigation:false];
                return;
            }
        }
        else if((endIndex.subIndexType == kMTSubIndexTypeExpSubscript && exponent.prefixedSubScript) || (endIndex.subIndexType == kMTSubIndexTypeExpSubscript && !exponent.prefixedSubScript)) {

            if([self isCursorPlacedAfterLayoutEnd:exponent.expSubScript.atoms :false]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeExponent isEndAtom:[self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms:false]];
                [self updateInterElementAtomsCount:exponent forIndex:_insertionIndex.endIndex];
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.expSubScript.atoms forIndex:endIndex isNextNavigation:false];
                return;
            }
        }
        
        else if(endIndex.subIndexType == kMTSubIndexTypeExponent && exponent.prefixedSubScript){
            if([self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms :false]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeExpBeforeSubscript isEndAtom:[self isCursorPlacedAfterLayoutEnd:exponent.prefixedSubScript.atoms:false]];
                [self updateInterElementAtomsCount:exponent forIndex:_insertionIndex.endIndex];
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.exponent.atoms forIndex:endIndex isNextNavigation:false];
                return;
            }
        } else if (endIndex.subIndexType == kMTSubIndexTypeExpBeforeSubscript) {
            if([self isCursorPlacedAfterLayoutEnd:exponent.prefixedSubScript.atoms :false]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
                _insertionIndex = _insertionIndex.levelDownToNextLayout;
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.prefixedSubScript.atoms forIndex:endIndex isNextNavigation:false];
                return;
            }
            
        }
        
        else if (endIndex.subIndexType == kMTSubIndexTypeExponent && !exponent.prefixedSubScript) {
            if([self isCursorPlacedAfterLayoutEnd:exponent.exponent.atoms :false]) {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
                _insertionIndex = _insertionIndex.levelDownToNextLayout;
            }
            else {
                [self navigateWithinInterElements:exponent childAtoms:exponent.exponent.atoms forIndex:endIndex isNextNavigation:false];
                return;
            }
        }
    }
}
    
#pragma mark Radical

- (void)levelDownAtomsForRadical:(MTRadical*)radical forIndex:(MTMathListIndex*)endIndex {
    
    if(endIndex.subIndexType == kMTSubIndexTypeDegree){
        if([self isCursorPlacedAfterLayoutEnd:radical.degree.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeRadicand isEndAtom:[self isCursorPlacedAfterLayoutEnd:radical.radicand.atoms:true]];
        }
        else {
            [self navigateWithinInterElements:radical childAtoms:radical.degree.atoms forIndex:endIndex isNextNavigation:true];
            return;
        };
        
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeRadicand){
        if([self isCursorPlacedAfterLayoutEnd:radical.radicand.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(radical.isAtLayoutEnd == false){
                radical.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            radical.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:radical childAtoms:radical.radicand.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
}

- (void)levelUpAtomsForRadical:(MTRadical*)radical forIndex:(MTMathListIndex*)endIndex {
    if(endIndex.subIndexType == kMTSubIndexTypeDegree){
        if([self isCursorPlacedAfterLayoutEnd:radical.degree.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:radical childAtoms:radical.degree.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if(endIndex.subIndexType == kMTSubIndexTypeRadicand){
        if([self isCursorPlacedAfterLayoutEnd:radical.radicand.atoms :false]) {
            if(radical.degree){
                if([self isCursorPlacedAfterLayoutEnd:radical.degree.atoms :false]) {
                    _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeDegree isEndAtom:[self isCursorPlacedAfterLayoutEnd:radical.degree.atoms:false]];
                    [self updateInterElementAtomsCount:radical forIndex:_insertionIndex.endIndex];
                }
                else {
                    [self navigateWithinInterElements:radical childAtoms:radical.degree.atoms forIndex:endIndex isNextNavigation:false];
                    return;
                }
            }
            else {
                _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
                _insertionIndex = _insertionIndex.levelDownToNextLayout;
            }
        }
        else {
            [self navigateWithinInterElements:radical childAtoms:radical.radicand.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
}

#pragma mark Large Operator

- (void)levelDownAtomsForLargeOperator:(MTLargeOperator*)largeOp forIndex:(MTMathListIndex*)endIndex {
    
    if(endIndex.subIndexType == kMTSubIndexTypeSuperscript){
        if([self isCursorPlacedAfterLayoutEnd:largeOp.superScript.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeSubscript isEndAtom:[self isCursorPlacedAfterLayoutEnd:largeOp.subScript.atoms:true]];
        }
        else {
            [self navigateWithinInterElements:largeOp childAtoms:largeOp.superScript.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeSubscript){
        if([self isCursorPlacedAfterLayoutEnd:largeOp.subScript.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(largeOp.isAtLayoutEnd == false){
                largeOp.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            largeOp.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:largeOp childAtoms:largeOp.subScript.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
    else if(endIndex.subIndexType == kMTSubIndexTypeLargeOpValueHolder || endIndex.subIndexType == kMTSubIndexTypeLargeOp){
        if([self isCursorPlacedAfterLayoutEnd:largeOp.holder.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(largeOp.isAtLayoutEnd == false){
                largeOp.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            largeOp.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:largeOp childAtoms:largeOp.holder.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
}

- (void)levelUpAtomsForLargeOperator:(MTLargeOperator*)largeOp forIndex:(MTMathListIndex*)endIndex {
    
    if(endIndex.subIndexType == kMTSubIndexTypeSuperscript){
        if([self isCursorPlacedAfterLayoutEnd:largeOp.superScript.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:largeOp childAtoms:largeOp.superScript.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if (endIndex.subIndexType == kMTSubIndexTypeSubscript){
        if([self isCursorPlacedAfterLayoutEnd:largeOp.subScript.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:kMTSubIndexTypeSuperscript isEndAtom:[self isCursorPlacedAfterLayoutEnd:largeOp.superScript.atoms:false]];
            [self updateInterElementAtomsCount:largeOp forIndex:_insertionIndex.endIndex];
        }
        else {
            [self navigateWithinInterElements:largeOp childAtoms:largeOp.subScript.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
    else if(endIndex.subIndexType == kMTSubIndexTypeLargeOpValueHolder || endIndex.subIndexType == kMTSubIndexTypeLargeOp){
        if([self isCursorPlacedAfterLayoutEnd:largeOp.holder.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:largeOp childAtoms:largeOp.holder.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
}

#pragma mark Index for Absolute Value

- (void)levelDownAtomsForAbsoluteValue:(MTAbsoluteValue*)absValue forIndex:(MTMathListIndex*)endIndex {
    
    if (endIndex.subIndexType == kMTSubIndexTypeAbsValue){
        if([self isCursorPlacedAfterLayoutEnd:absValue.absHolder.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(absValue.isAtLayoutEnd == false){
                absValue.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            absValue.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:absValue childAtoms:absValue.absHolder.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
}

- (void)levelUpAtomsForAbsoluteValue:(MTAbsoluteValue*)absValue forIndex:(MTMathListIndex*)endIndex {
    
    if(endIndex.subIndexType == kMTSubIndexTypeAbsValue){
        if([self isCursorPlacedAfterLayoutEnd:absValue.absHolder.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:absValue childAtoms:absValue.absHolder.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
}

#pragma mark Index for Accent

- (void)levelDownAtomsForAccent:(MTAccent*)accent forIndex:(MTMathListIndex*)endIndex {
    
    if (endIndex.subIndexType == kMTSubIndexTypeOverbar){
        if([self isCursorPlacedAfterLayoutEnd:accent.innerList.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(accent.isAtLayoutEnd == false){
                accent.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            accent.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:accent childAtoms:accent.innerList.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
}

- (void)levelUpAtomsForAccent:(MTAccent*)accent forIndex:(MTMathListIndex*)endIndex {
    if(endIndex.subIndexType == kMTSubIndexTypeOverbar){
        if([self isCursorPlacedAfterLayoutEnd:accent.innerList.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:accent childAtoms:accent.innerList.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
}

#pragma mark Index for Inner

- (void)levelDownAtomsForInner:(MTInner*)inner forIndex:(MTMathListIndex*)endIndex {
    
    if (endIndex.subIndexType == kMTSubIndexTypeInner){
        if([self isCursorPlacedAfterLayoutEnd:inner.innerList.atoms :true]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
            if(inner.isAtLayoutEnd == false){
                inner.isAtLayoutEnd = true;
            }
            [self levelDownToInterAtoms:nil];
            inner.isAtLayoutEnd = false;
        }
        else {
            [self navigateWithinInterElements:inner childAtoms:inner.innerList.atoms forIndex:endIndex isNextNavigation:true];
            return;
        }
    }
}

- (void)levelUpAtomsForInner:(MTInner*)inner forIndex:(MTMathListIndex*)endIndex {
    if(endIndex.subIndexType == kMTSubIndexTypeInner){
        if([self isCursorPlacedAfterLayoutEnd:inner.innerList.atoms :false]) {
            _insertionIndex = [_insertionIndex replaceSubIndex:endIndex withSubIndexType:endIndex.subIndexType isEndAtom:true];
            _insertionIndex = _insertionIndex.levelDownToNextLayout;
        }
        else {
            [self navigateWithinInterElements:inner childAtoms:inner.innerList.atoms forIndex:endIndex isNextNavigation:false];
            return;
        }
    }
}


#pragma mark - Magnifying Glass

- (NSUInteger)loadPrevious {
    NSUInteger previousIndex = _insertionIndex.atomIndex - 1;
    NSUInteger zeroIndex = 0;
    if (previousIndex >= zeroIndex && previousIndex <= self.mathList.atoms.count) {
      _insertionIndex = [MTMathListIndex level0Index:previousIndex];//_insertionIndex.previous;
        //[self resetAtomIndex];
        [self insertionPointChanged];
        
        if ([self.delegate respondsToSelector:@selector(didTapPreviousArrow:withCaretView:)]) {
            [self.delegate didTapPreviousArrow:self withCaretView:_caretView];
        }
    }
    
    return _insertionIndex.atomIndex;
}

- (NSUInteger)loadNext {
    NSUInteger nextIndex = _insertionIndex.atomIndex + 1;
    NSUInteger zeroIndex = 0;
    if (nextIndex >= zeroIndex && nextIndex <= self.mathList.atoms.count) {
        _insertionIndex = [MTMathListIndex level0Index:nextIndex];//_insertionIndex.next;
        //[self resetAtomIndex];
        [self insertionPointChanged];
        
        if ([self.delegate respondsToSelector:@selector(didTapNextArrow:withCaretView:)]) {
            [self.delegate didTapNextArrow:self withCaretView:_caretView];
        }
    }
    
    return _insertionIndex.atomIndex;
}

- (MTMathListDisplay*)fetchDisplayList{
    return [self.label getDisplayList:self.mathList];
}

#pragma mark - Touch Events

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    [self moveCaretToPoint:[[touches anyObject] locationInView:self]];
    
    if ([self.delegate respondsToSelector:@selector(touchesBegan)]) {
        [self.delegate touchesBegan];
    }
    
    [super touchesBegan:touches withEvent:event];
    [self.nextResponder touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    CGPoint touchLocation = [[touches anyObject] locationInView:self];
    [self moveCaretToPoint:touchLocation];
    
    if ([self.delegate respondsToSelector:@selector(touchesMoved:withCaretView:withTouchLocation:)]) {
        [self.delegate touchesMoved:self withCaretView:_caretView withTouchLocation:touchLocation];
    }
    
    [super touchesMoved:touches withEvent:event];
    [self.nextResponder touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    if ([self.delegate respondsToSelector:@selector(touchesEnded)]) {
        [self.delegate touchesEnded];
    }
    
    [super touchesEnded:touches withEvent:event];
    [self.nextResponder touchesEnded:touches withEvent:event];
    
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    if ([self.delegate respondsToSelector:@selector(touchesCancelled)]) {
        [self.delegate touchesCancelled];
    }
    
    [super touchesCancelled:touches withEvent:event];
    [self.nextResponder touchesCancelled:touches withEvent:event];
    
}

@end
