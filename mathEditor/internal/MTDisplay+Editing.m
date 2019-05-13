//
//  MTDisplay+Editing.m
//
//  Created by Kostub Deshmukh on 9/6/13.
//  Copyright (C) 2013 MathChat
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import <CoreText/CoreText.h>

#import "MTDisplay+Editing.h"
#import "MTMathList+Editing.h"

static CGPoint kInvalidPosition = { -1, -1};
// Number of pixels outside the bound to allow a point to be considered as part of the bounds.
static CGFloat kPixelDelta = 2;

#pragma mark Unicode functions

NSUInteger numCodePointsInRange(NSString* str, NSRange range) {
    if (range.length > 0) {
        // doesn't work correctly if range is 0
        NSRange grown = [str rangeOfComposedCharacterSequencesForRange:range];
        
        unichar buffer[grown.length];
        [str getCharacters:buffer range:grown];
        int count = 0;
        for (int i = 0; i < grown.length; i++) {
            count++;
            // we check both high and low due to work for both endianess
            if (CFStringIsSurrogateHighCharacter(buffer[i]) || CFStringIsSurrogateLowCharacter(buffer[i])) {
                // skip the next character
                i++;
            }
        }
        return count;
    }
    return 0;
}

static NSUInteger codePointIndexToStringIndex(NSString* str, const NSUInteger codePointIndex) {
    unichar buffer[str.length];
    [str getCharacters:buffer range:NSMakeRange(0, str.length)];
    int codePointCount = 0;
    for (int i = 0; i < str.length; i++, codePointCount++) {
        if (codePointCount == codePointIndex) {
            return i;  // this is the string index
        }
        // we check both high and low due to work for both endianess
        if (CFStringIsSurrogateHighCharacter(buffer[i]) || CFStringIsSurrogateLowCharacter(buffer[i])) {
            // skip the next character
            i++;
        }
    }
    
    // the index is out of range
    return NSNotFound;
}

#pragma mark - Distance utilities
// Calculates the manhattan distance from a point to the nearest boundary of the rectangle
static CGFloat distanceFromPointToRect(CGPoint point, CGRect rect) {
    CGFloat distance = 0;
    if (point.x < rect.origin.x) {
        distance += (rect.origin.x - point.x);
    } else if (point.x > CGRectGetMaxX(rect)) {
        distance += point.x - CGRectGetMaxX(rect);
    }
    
    if (point.y < rect.origin.y) {
        distance += (rect.origin.y - point.y);
    } else if (point.y > CGRectGetMaxY(rect)) {
        distance += point.y - CGRectGetMaxY(rect);
    }
    return distance;
}

# pragma mark - MTDisplay

@implementation MTDisplay (Editing)

// Empty implementations for the base class

- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    return nil;
}

- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    return kInvalidPosition;
}

- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color
{
}

- (void)highlightWithColor:(UIColor *)color
{
}
@end

# pragma mark - MTGlyphDisplay

@interface MTGlyphDisplay (Editing)

- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point;
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index;
@end

@implementation MTGlyphDisplay (Editing)

- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the pair, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the pair
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    }
    else{
        return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[MTMathListIndex level0Index:self.range.location] type:kMTSubIndexTypeNone];
    }
}

- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
     return CGPointMake(self.position.x, self.position.y);
}


@end
# pragma mark - MTCTLineDisplay

@interface MTCTLineDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

@end

@implementation MTCTLineDisplay (Editing)

- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // Convert the point to the reference of the CTLine
    CGPoint relativePoint = CGPointMake(point.x - self.position.x, point.y - self.position.y);
    CFIndex index = CTLineGetStringIndexForPosition(self.line, relativePoint);
    if (index == kCFNotFound) {
        return nil;
    }
    // The index returned is in UTF-16, translate to codepoint index.
    // NSUInteger codePointIndex = stringIndexToCodePointIndex(self.attributedString.string, index);
    // Convert the code point index to an index into the mathlist
    NSUInteger mlIndex = [self convertToMathListIndex:index];
    // index will be between 0 and _range.length inclusive
    NSAssert(mlIndex >= 0 && mlIndex <= self.range.length, @"Returned index out of range: %ld, range (%@, %@)", index, @(self.range.location), @(self.range.length));
    // translate to the current index
    MTMathListIndex* listIndex = [MTMathListIndex level0Index:self.range.location + mlIndex];
    return listIndex;
}

- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    CGFloat offset;
    NSAssert(index.subIndexType == kMTSubIndexTypeNone, @"Index in a CTLineDisplay cannot have sub indexes.");
    if (index.atomIndex == NSMaxRange(self.range)) {
        offset = self.width;
    } else {
        NSAssert(NSLocationInRange(index.atomIndex, self.range), @"Index %@ not in range %@", index, NSStringFromRange(self.range));
        NSUInteger strIndex = [self mathListIndexToStringIndex:index.atomIndex - self.range.location];
        //CFIndex charIndex = codePointIndexToStringIndex(self.attributedString.string, strIndex);
        offset = CTLineGetOffsetForStringIndex(self.line, strIndex, NULL);
    }
    return CGPointMake(self.position.x + offset, self.position.y);
}


- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(NSLocationInRange(index.atomIndex, self.range));
    assert(index.subIndexType == kMTSubIndexTypeNone || index.subIndexType == kMTSubIndexTypeNucleus);
    if (index.subIndexType == kMTSubIndexTypeNucleus) {
        NSAssert(false, @"Nucleus highlighting not supported yet");
    }
    // index is in unicode code points, while attrString is not
    CFIndex charIndex = codePointIndexToStringIndex(self.attributedString.string, index.atomIndex - self.range.location);
    assert(charIndex != NSNotFound);
    
    NSMutableAttributedString* attrStr = self.attributedString.mutableCopy;
    [attrStr addAttribute:(NSString*)kCTForegroundColorAttributeName value:(id)[color CGColor]
                    range:[attrStr.string rangeOfComposedCharacterSequenceAtIndex:charIndex]];
    self.attributedString = attrStr;
}

- (void)highlightWithColor:(UIColor *)color
{
    NSMutableAttributedString* attrStr = self.attributedString.mutableCopy;
    [attrStr addAttribute:(NSString*)kCTForegroundColorAttributeName value:(id)[color CGColor]
                    range:NSMakeRange(0, attrStr.length)];
    self.attributedString = attrStr;
}

// Convert the index into the current string to an index into the mathlist. These may not be the same since a single
// math atom may have multiple characters.
- (NSUInteger) convertToMathListIndex:(NSUInteger) strIndex
{
    NSUInteger strLenCovered = 0;
    for (NSUInteger mlIndex = 0; mlIndex < self.atoms.count; mlIndex++) {
        if (strLenCovered >= strIndex) {
            return mlIndex;
        }
        MTMathAtom* atom = self.atoms[mlIndex];
        strLenCovered += atom.nucleus.length;
    }
    // By the time we come to the end of the string, we should have covered all the characters.
    NSAssert(strLenCovered >= strIndex, @"StrIndex should not be more than the len covered");
    return self.atoms.count;
}

- (NSUInteger) mathListIndexToStringIndex:(NSUInteger) mlIndex
{
    NSAssert(mlIndex < self.atoms.count, @"Index %@ not in range %@", @(mlIndex), @(self.atoms.count));
    NSUInteger strIndex = 0;
    for (NSUInteger i = 0; i < mlIndex; i++) {
        MTMathAtom* atom = self.atoms[i];
        strIndex += atom.nucleus.length;
    }
    return strIndex;
}

@end

#pragma mark - MTFractionDisplay

@interface MTFractionDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;

@end

@implementation MTFractionDisplay (Editing)

- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // We can be before the fraction or after the fraction
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the fraction, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the fraction
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    } else {
        // we can be either near the numerator or the denominator
        CGFloat numeratorDistance = distanceFromPointToRect(point, self.numerator.displayBounds);
        CGFloat denominatorDistance = distanceFromPointToRect(point, self.denominator.displayBounds);
        CGFloat wholeDistance = distanceFromPointToRect(point, self.whole.displayBounds);
        if (wholeDistance < numeratorDistance && wholeDistance < denominatorDistance) {
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.whole closestIndexToPoint:point] type:kMTSubIndexTypeWhole];
        }
        else if (numeratorDistance < denominatorDistance) {
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.numerator closestIndexToPoint:point] type:kMTSubIndexTypeNumerator];
        } else {
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.denominator closestIndexToPoint:point] type:kMTSubIndexTypeDenominator];
        }
    }
}

// Seems never used
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    // draw a caret before the fraction
    return CGPointMake(self.position.x, self.position.y);
}

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    [self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.numerator highlightWithColor:color];
    [self.denominator highlightWithColor:color];
}

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
        case kMTSubIndexTypeNumerator:
            return self.numerator;
            
        case kMTSubIndexTypeDenominator:
            return self.denominator;
            
        case kMTSubIndexTypeWhole:
            return self.whole;
            
        case kMTSubIndexTypeDegree:
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeSubscript:
        case kMTSubIndexTypeSuperscript:
        case kMTSubIndexTypeNone:
            NSAssert(false, @"Not a fraction subtype %d", type);
            return nil;
    }
    return nil;
}

@end


#pragma mark - MTOrderedDisplay

@interface MTOrderedPairDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;


@end

@implementation MTOrderedPairDisplay (Editing)


- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // We can be before the pair or after the pair
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the pair, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the pair
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    } else {
        // we can be either near the left or the right pair
        CGFloat leftPairDistance = distanceFromPointToRect(point, self.leftPair.displayBounds);
        CGFloat rightPairDistance = distanceFromPointToRect(point, self.rightPair.displayBounds);
        if (leftPairDistance < rightPairDistance) {
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.leftPair closestIndexToPoint:point] type:kMTSubIndexTypeLeftOperand];
        } else {
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.rightPair closestIndexToPoint:point] type:kMTSubIndexTypeRightOperand];
        }
        return nil;
    }
}

// Seems never used
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    // draw a caret before the fraction
    return CGPointMake(self.position.x, self.position.y);
}

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    [self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.leftPair highlightWithColor:color];
    [self.rightPair highlightWithColor:color];
}


- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
        case kMTSubIndexTypeLeftOperand:
            return self.leftPair;
            
        case kMTSubIndexTypeRightOperand:
            return self.rightPair;
            
        case kMTSubIndexTypeDegree:
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeSubscript:
        case kMTSubIndexTypeSuperscript:
        case kMTSubIndexTypeNone:
            NSAssert(false, @"Not a fraction subtype %d", type);
            return nil;
    }
    return nil;
}



@end

#pragma mark - MTBinomialMatrixDisplay

@interface MTBinomialMatrixDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;


@end

@implementation MTBinomialMatrixDisplay (Editing)


- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // We can be before the matrix or after the matrix
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the matrix, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the matrix
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    } else {
        
        //CGFloat caretDistanceForR0C0 = distanceFromPointToRect(point, self.row0Column0.displayBounds);
        //CGFloat caretDistanceForR0C1 = distanceFromPointToRect(point, self.row0Column1.displayBounds);
        //CGFloat caretDistanceForR1C0 = distanceFromPointToRect(point, self.row1Column0.displayBounds);
        //CGFloat caretDistanceForR1C1 = distanceFromPointToRect(point, self.row1Column1.displayBounds);
        if(CGRectContainsPoint(self.row0Column0.displayBounds, point)){
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.row0Column0 closestIndexToPoint:point] type:kMTSubIndexTypeRow0Col0];
        }else if(CGRectContainsPoint(self.row0Column1.displayBounds, point)){
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.row0Column1 closestIndexToPoint:point] type:kMTSubIndexTypeRow0Col1];
        }else if(CGRectContainsPoint(self.row1Column0.displayBounds, point)){
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.row1Column0 closestIndexToPoint:point] type:kMTSubIndexTypeRow1Col0];
        }else if(CGRectContainsPoint(self.row1Column1.displayBounds, point)){
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.row1Column1 closestIndexToPoint:point] type:kMTSubIndexTypeRow1Col1];
        }
        return nil;
    }
}

// Seems never used
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    // draw a caret before the matrix
    return CGPointMake(self.position.x, self.position.y);
}

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    //[self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.row0Column0 highlightWithColor:color];
    [self.row0Column1 highlightWithColor:color];
    [self.row1Column0 highlightWithColor:color];
    [self.row1Column1 highlightWithColor:color];
}


- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
        case kMTSubIndexTypeRow0Col0:
            return self.row0Column0;
        case kMTSubIndexTypeRow0Col1:
            return self.row0Column1;
        case kMTSubIndexTypeRow1Col0:
            return self.row1Column0;
        case kMTSubIndexTypeRow1Col1:
            return self.row1Column1;
        case kMTSubIndexTypeLeftOperand:
        case kMTSubIndexTypeRightOperand:
        case kMTSubIndexTypeDegree:
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeSubscript:
        case kMTSubIndexTypeSuperscript:
        case kMTSubIndexTypeNone:
            return nil;
    }
    return nil;
}

@end

#pragma mark - MTAbsoluteValueDisplay

@interface MTAbsoluteValueDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;

@end

@implementation MTAbsoluteValueDisplay (Editing)

- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // We can be before the fraction or after the fraction
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the fraction, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the fraction
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    } else {
        
        return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.absPlaceholder closestIndexToPoint:point] type:kMTSubIndexTypeAbsValue];
    }
}

// Seems never used
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    // draw a caret before the fraction
    return CGPointMake(self.position.x, self.position.y);
}

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    [self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.absPlaceholder highlightWithColor:color];
}

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
        case kMTSubIndexTypeAbsValue:
            return self.absPlaceholder;
            
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeNumerator:
        case kMTSubIndexTypeWhole:
        case kMTSubIndexTypeDegree:
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeSubscript:
        case kMTSubIndexTypeSuperscript:
        case kMTSubIndexTypeNone:
            NSAssert(false, @"Not a abs subtype %d", type);
            return nil;
    }
    return nil;
}

@end


#pragma mark - MTAccentDisplay

@interface MTAccentDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;

@end

@implementation MTAccentDisplay (Editing)


- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // We can be before the radical or after the radical
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the radical, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the radical
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    } else {
        // we are in the radical
        CGFloat degreeDistance = distanceFromPointToRect(point, self.accentee.displayBounds);
        
        return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.accentee closestIndexToPoint:point] type:kMTSubIndexTypeOverbar];
    }
    //        if (degreeDistance < radicandDistance) {
    //            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.degree closestIndexToPoint:point] type:kMTSubIndexTypeDegree];
    //        } else {
    //            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.radicand closestIndexToPoint:point] type:kMTSubIndexTypeRadicand];
    //        }
    
    // }
}

// TODO seems unused
//- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
//{
//    assert(index.subIndexType == kMTSubIndexTypeNone);
//    // draw a caret
//    return CGPointMake(self.position.x, self.position.y);
//}
//}

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    [self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.accentee highlightWithColor:color];
}

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
            
        case kMTSubIndexTypeOverbar:
            return self.accentee;
            
        case kMTSubIndexTypeNumerator:
            
        case kMTSubIndexTypeDenominator:
            
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeSubscript:
        case kMTSubIndexTypeSuperscript:
        case kMTSubIndexTypeNone:
            NSAssert(false, @"Not a radical subtype %d", type);
            return nil;
    }
    return nil;
}

@end

#pragma mark - MTInnerDisplay

@interface MTInnerDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
//- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;
//
//- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;

@end

@implementation MTInnerDisplay (Editing)


- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the pair, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if ((point.x > self.position.x + self.width + kPixelDelta) && self.right != nil) {
        // we are after the pair
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    }
    else {
        return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.innerList closestIndexToPoint:point] type:kMTSubIndexTypeInner];
        //        return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[MTMathListIndex level0Index:self.range.location] type:kMTSubIndexTypeInner];
    }
}

// TODO seems unused
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    // draw a caret
    return CGPointMake(self.position.x, self.position.y);
}
- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    [self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.innerList highlightWithColor:color];
}

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
        case kMTSubIndexTypeInner:
            return self.innerList;
        case kMTSubIndexTypeOverbar:
        case kMTSubIndexTypeNumerator:
            
        case kMTSubIndexTypeDenominator:
            
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeSubscript:
        case kMTSubIndexTypeSuperscript:
            
        case kMTSubIndexTypeNone:
            NSAssert(false, @"Not a radical subtype %d", type);
            return nil;
    }
    return nil;
}

@end


#pragma mark - MTRadicalDisplay

@interface MTRadicalDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;

@end

@implementation MTRadicalDisplay (Editing)


- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // We can be before the radical or after the radical
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the radical, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the radical
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    } else {
        // we are in the radical
        CGFloat degreeDistance = distanceFromPointToRect(point, self.degree.displayBounds);
        CGFloat radicandDistance = distanceFromPointToRect(point, self.radicand.displayBounds);
        
        if (degreeDistance < radicandDistance) {
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.degree closestIndexToPoint:point] type:kMTSubIndexTypeDegree];
        } else {
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.radicand closestIndexToPoint:point] type:kMTSubIndexTypeRadicand];
        }
        
    }
}

// TODO seems unused
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    // draw a caret
    return CGPointMake(self.position.x, self.position.y);
}

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    [self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.radicand highlightWithColor:color];
}

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
            
        case kMTSubIndexTypeRadicand:
            return self.radicand;
        case kMTSubIndexTypeDegree:
            return self.degree;
        case kMTSubIndexTypeNumerator:
            
        case kMTSubIndexTypeDenominator:
            
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeSubscript:
        case kMTSubIndexTypeSuperscript:
        case kMTSubIndexTypeLeftOperand:
        case kMTSubIndexTypeRightOperand:
        case kMTSubIndexTypeNone:
            NSAssert(false, @"Not a radical subtype %d", type);
            return nil;
    }
    return nil;
}

@end

#pragma mark - MTExponentDisplay

@interface MTExponentDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;

@end

@implementation MTExponentDisplay (Editing)


- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // We can be before the radical or after the radical
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the radical, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the radical
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    } else {
        
        if(CGRectContainsPoint(self.exponentBase.displayBounds, point)){
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.exponentBase closestIndexToPoint:point] type:kMTSubIndexTypeExponent];
        }else if(CGRectContainsPoint(self.expSuperscript.displayBounds, point)){
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.expSuperscript closestIndexToPoint:point] type:kMTSubIndexTypeExpSuperscript];
        }else if(CGRectContainsPoint(self.expSubscript.displayBounds, point)){
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.expSubscript closestIndexToPoint:point] type:kMTSubIndexTypeExpSubscript];
        }
        else if(CGRectContainsPoint(self.prefixedSubscript.displayBounds, point)){
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.prefixedSubscript closestIndexToPoint:point] type:kMTSubIndexTypeExpBeforeSubscript];
        }
        return nil;
    }
}

// TODO seems unused
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    // draw a caret
    return CGPointMake(self.position.x, self.position.y);
}

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    [self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.exponentBase highlightWithColor:color];
}

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
            
        case kMTSubIndexTypeExponent:
            return self.exponentBase;
        case kMTSubIndexTypeExpSuperscript:
            return self.expSuperscript;
        case kMTSubIndexTypeExpSubscript:
            return self.expSubscript;
        case kMTSubIndexTypeExpBeforeSubscript:
            return self.prefixedSubscript;
        case kMTSubIndexTypeNumerator:
        case kMTSubIndexTypeDegree:
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeSubscript:
        case kMTSubIndexTypeSuperscript:
        case kMTSubIndexTypeNone:
            NSAssert(false, @"Not a exponent subtype %d", type);
            return nil;
    }
    return nil;
}

@end


#pragma mark - MTMathListDisplay

@interface MTMathListDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

@end


#pragma mark - MTLargeOpDisplay

@interface MTLargeOpLimitsDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;

@end

@implementation MTLargeOpLimitsDisplay (Editing)


- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // We can be before the radical or after the radical
    if (point.x < self.position.x - kPixelDelta) {
        // we are before the radical, so
        return [MTMathListIndex level0Index:self.range.location];
    } else if (point.x > self.position.x + self.width + kPixelDelta) {
        // we are after the radical
        return [MTMathListIndex level0Index:NSMaxRange(self.range)];
    } else {
        // we are in the radical
        if(self.lowerLimit || self.upperLimit){
            CGFloat degreeDistance = distanceFromPointToRect(point, self.upperLimit.displayBounds);
            CGFloat radicandDistance = distanceFromPointToRect(point, self.lowerLimit.displayBounds);
            
            if (degreeDistance < radicandDistance) {
                return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.upperLimit closestIndexToPoint:point] type:kMTSubIndexTypeSuperscript];
            } else {
                return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.lowerLimit closestIndexToPoint:point] type:kMTSubIndexTypeSubscript];
            }
        }
        else {
            return [MTMathListIndex indexAtLocation:self.range.location withSubIndex:[self.holder closestIndexToPoint:point] type:kMTSubIndexTypeLargeOpValueHolder];
        }
    }
}

// TODO seems unused
- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    // draw a caret
    return CGPointMake(self.position.x, self.position.y);
}

- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    assert(index.subIndexType == kMTSubIndexTypeNone);
    [self highlightWithColor:color];
}

- (void)highlightWithColor:(UIColor *)color
{
    [self.upperLimit highlightWithColor:color];
}

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
{
    switch (type) {
        case kMTSubIndexTypeSubscript:
            return self.upperLimit;
            
        case kMTSubIndexTypeSuperscript:
            return self.lowerLimit;
        case kMTSubIndexTypeLargeOpValueHolder:
            return self.holder;
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeDegree:
        case kMTSubIndexTypeNumerator:
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeNucleus:
        case kMTSubIndexTypeNone:
            NSAssert(false, @"Not a radical subtype %d", type);
            return nil;
    }
    return nil;
}

@end


#pragma mark - MTMathListDisplay

@interface MTMathListDisplay (Editing)

// Find the index in the mathlist before which a new character should be inserted. Returns nil if it cannot find the index.
- (MTMathListIndex*) closestIndexToPoint:(CGPoint) point;

// The bounds of the display indicated by the given index
- (CGPoint) caretPositionForIndex:(MTMathListIndex*) index;

// Highlight the character(s) at the given index.
- (void) highlightCharacterAtIndex:(MTMathListIndex*) index color:(UIColor*) color;

- (void)highlightWithColor:(UIColor *)color;

- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type;


@end

@implementation MTMathListDisplay (Editing)

//- (MTMathListDisplay*) subAtomForIndexType:(MTMathListSubIndexType) type
//{
//    switch (type) {
//        case kMTSubIndexTypeLeftOperand:
//
//        case kMTSubIndexTypeRightOperand:
//
//        case kMTSubIndexTypeDegree:
//        case kMTSubIndexTypeRadicand:
//        case kMTSubIndexTypeNucleus:
//        case kMTSubIndexTypeSubscript:
//        case kMTSubIndexTypeSuperscript:
//        case kMTSubIndexTypeTable:
//            return self;
//        case kMTSubIndexTypeNone:
//            //NSAssert(false, @"Not a fraction subtype %d", type);
//            return nil;
//    }
//}


- (MTMathListIndex *)closestIndexToPoint:(CGPoint)point
{
    // the origin of for the subelements of a MTMathList is the current position, so translate the current point to our origin.
    CGPoint translatedPoint = CGPointMake(point.x - self.position.x, point.y - self.position.y + self.shiftBottom);
    
    MTDisplay* closest = nil;
    NSMutableArray* xbounds = [NSMutableArray array];
    CGFloat minDistance = CGFLOAT_MAX;
    for (MTDisplay* atom in self.subDisplays) {
        CGRect bounds = atom.displayBounds;
        CGFloat maxBoundsX = CGRectGetMaxX(bounds);
        
        if (bounds.origin.x - kPixelDelta <= translatedPoint.x && translatedPoint.x <= maxBoundsX + kPixelDelta) {
            [xbounds addObject:atom];
        }
        
        CGFloat distance = distanceFromPointToRect(translatedPoint, bounds);
        if (distance < minDistance) {
            closest = atom;
            minDistance = distance;
        }
    }
    MTDisplay* atomWithPoint = nil;
    if (xbounds.count == 0) {
        if (translatedPoint.x <= -kPixelDelta) {
            // all the way to the left
            return [MTMathListIndex level0Index:self.range.location];
        } else if (translatedPoint.x >= self.width + kPixelDelta) {
            // all the way to the right
            return [MTMathListIndex level0Index:NSMaxRange(self.range)];
        } else {
            // It is within the mathlist but not within the x bounds of any sublist. Use the closest in that case.
            atomWithPoint = closest;
        }
    } else if (xbounds.count == 1) {
        atomWithPoint = xbounds[0];
        if (translatedPoint.x >= self.width - kPixelDelta) {
            // The point is close to the end. Only use the selected x bounds if the y is within range.
            if (translatedPoint.y <= CGRectGetMinY(atomWithPoint.displayBounds) - kPixelDelta) {
                // The point is less than the y including the delta. Move the cursor to the end rather than in this atom.
                return [MTMathListIndex level0Index:self.range.location];
            }
        }
    } else {
        // Use the closest since there are more than 2 sublists which have this x position.
        atomWithPoint = closest;
    }
    
    if (!atomWithPoint) {
        return nil;
    }
    
    MTMathListIndex* index = [atomWithPoint closestIndexToPoint:(CGPoint)translatedPoint];
    if ([atomWithPoint isKindOfClass:[MTMathListDisplay class]]) {
        
        MTMathListDisplay* closestLine = (MTMathListDisplay*) atomWithPoint;
        
        if(closestLine.type == kMTLinePositionRegular || closestLine.type == kMTLinePositionBeforeSubscript){
            return index;
            
        }
        
        NSAssert(closestLine.type == kMTLinePositionSubscript || closestLine.type == kMTLinePositionSuperscript, @"MTLine type regular inside an MTLine - shouldn't happen");
        // This is a subscript or a superscript, return the right type of subindex
        MTMathListSubIndexType type = (closestLine.type == kMTLinePositionSubscript) ? kMTSubIndexTypeSubscript : kMTSubIndexTypeSuperscript;
        // The index of the atom this denotes.
        NSAssert(closestLine.index != NSNotFound, @"Index is not set for a subscript/superscript");
        return [MTMathListIndex indexAtLocation:closestLine.index withSubIndex:index type:type];
        
        
    } else if (atomWithPoint.hasScript) {
        // The display list has a subscript or a superscript. If the index is at the end of the atom, then we need to put it before the sub/super script rather than after.
        if (index.atomIndex == NSMaxRange(atomWithPoint.range)) {
            return [MTMathListIndex indexAtLocation:index.atomIndex - 1 withSubIndex:[MTMathListIndex level0Index:1] type:kMTSubIndexTypeNucleus];
        }
    }
    return index;
}

- (MTDisplay*) subAtomForIndex:(MTMathListIndex*) index
{
    // Inside the range
    if (index.subIndexType == kMTSubIndexTypeSuperscript || index.subIndexType == kMTSubIndexTypeSubscript || index.subIndexType == kMTSubIndexTypeBeforeSubscript) {
        for (MTDisplay* atom in self.subDisplays) {
            
            if ([atom isKindOfClass:[MTMathListDisplay class]]) {
                MTMathListDisplay* lineAtom = (MTMathListDisplay*) atom;
                if (index.atomIndex == lineAtom.index) {
                    // this is the right character for the sub/superscript
                    // Check that it's type matches the index
                    if (((lineAtom.type == kMTLinePositionSubscript && index.subIndexType == kMTSubIndexTypeSubscript)
                        || (lineAtom.type == kMTLinePositionSuperscript && index.subIndexType == kMTSubIndexTypeSuperscript) || (lineAtom.type == kMTLinePositionBeforeSubscript && index.subIndexType == kMTSubIndexTypeBeforeSubscript))) {
                        return lineAtom;
                    }
                }
            }
            else if([atom isKindOfClass:[MTLargeOpLimitsDisplay class]]){
                
                MTLargeOpLimitsDisplay* lineAtom1 = (MTLargeOpLimitsDisplay*) atom;
                if(lineAtom1.upperLimit.index == index.atomIndex || lineAtom1.lowerLimit.index == index.atomIndex){
                    
                    if (lineAtom1.upperLimit.type == kMTLinePositionSuperscript && index.subIndexType == kMTSubIndexTypeSuperscript) {
                        return lineAtom1.upperLimit;
                    }

                    else if(lineAtom1.lowerLimit.type == kMTLinePositionSubscript && index.subIndexType == kMTSubIndexTypeSubscript){
                        return lineAtom1.lowerLimit;
                    }
                }
            }
        }
    } else {
        for (MTDisplay* atom in self.subDisplays) {
            //if (![atom isKindOfClass:[MTMathListDisplay class]] && NSLocationInRange(index.atomIndex, atom.range)) {
            if (NSLocationInRange(index.atomIndex, atom.range)) {
                
                // not a subscript/superscript and
                // jackpot, the index is in the range of this atom.
                switch (index.subIndexType) {
                    case kMTSubIndexTypeNone:
                    case kMTSubIndexTypeNucleus:
                        return atom;
                        
                    case kMTSubIndexTypeDegree:
                    case kMTSubIndexTypeRadicand:
                        if ([atom isKindOfClass:[MTRadicalDisplay class]]) {
                            MTRadicalDisplay *radical = (MTRadicalDisplay *) atom;
                            return [radical subAtomForIndexType:index.subIndexType];
                        } else {
                            NSLog(@"No radical at index: %lu", (unsigned long)index.atomIndex);
                            return nil;
                        }
                    case kMTSubIndexTypeExponent:
                    case kMTSubIndexTypeExpSubscript:
                    case kMTSubIndexTypeExpSuperscript:
                    case kMTSubIndexTypeExpBeforeSubscript :
                        if ([atom isKindOfClass:[MTExponentDisplay class]]) {
                            MTExponentDisplay *exponent = (MTExponentDisplay *) atom;
                            return [exponent subAtomForIndexType:index.subIndexType];
                        } else {
                            NSLog(@"No exponent display at index: %lu", (unsigned long)index.atomIndex);
                            return nil;
                        }
    
                    case kMTSubIndexTypeNumerator:
                    case kMTSubIndexTypeDenominator:
                    case kMTSubIndexTypeWhole:
                        if ([atom isKindOfClass:[MTFractionDisplay class]]) {
                            MTFractionDisplay* frac = (MTFractionDisplay*) atom;
                            return [frac subAtomForIndexType:index.subIndexType];
                        } else {
                            NSLog(@"No fraction at index: %lu", (unsigned long)index.atomIndex);
                            return nil;
                        }
                        
                    case kMTSubIndexTypeLeftOperand:
                    case kMTSubIndexTypeRightOperand:{
                        
                        if ([atom isKindOfClass:[MTOrderedPairDisplay class]]) {
                            MTOrderedPairDisplay *pair = (MTOrderedPairDisplay*)atom;
                            return [pair subAtomForIndexType:index.subIndexType];
                        } else {
                            NSLog(@"No pair at index: %lu", (unsigned long)index.atomIndex);
                            return nil;
                        }
                        break;
                    }
                    case kMTSubIndexTypeRow0Col0:
                    case kMTSubIndexTypeRow0Col1:
                    case kMTSubIndexTypeRow1Col0:
                    case kMTSubIndexTypeRow1Col1:{
                        
                        if ([atom isKindOfClass:[MTBinomialMatrixDisplay class]]) {
                            MTBinomialMatrixDisplay* matrix = (MTBinomialMatrixDisplay*)atom;
                            return [matrix subAtomForIndexType:index.subIndexType];
                        } else {
                            NSLog(@"No matrix at index: %lu", (unsigned long)index.atomIndex);
                            return nil;
                        }
                        break;
                    }
                    case kMTSubIndexTypeOverbar:{
                        if ([atom isKindOfClass:[MTAccentDisplay class]]) {
                            MTAccentDisplay *accent = (MTAccentDisplay *) atom;
                            return [accent subAtomForIndexType:index.subIndexType];
                        } else {
                            NSLog(@"No accent at index: %lu", (unsigned long)index.atomIndex);
                            return nil;
                        }
                        break;
                    }
                    case kMTSubIndexTypeLargeOp:
                    case kMTSubIndexTypeLargeOpValueHolder:{
                        if ([atom isKindOfClass:[MTLargeOpLimitsDisplay class]]) {
                            MTLargeOpLimitsDisplay *largeOp = (MTLargeOpLimitsDisplay *) atom;
                            if(largeOp.holder){
                                return [largeOp subAtomForIndexType:index.subIndexType];
                            }
                        }else if([atom isKindOfClass:[MTGlyphDisplay class]]){
                            return atom;
                        }
                        else {
                            NSLog(@"No Large Op at index: %lu", (unsigned long)index.atomIndex);
                            return nil;
                        }
                        break;
                    }
                    case kMTSubIndexTypeAbsValue:{
                        if ([atom isKindOfClass:[MTAbsoluteValueDisplay class]]) {
                            MTAbsoluteValueDisplay *absDisplay = (MTAbsoluteValueDisplay *) atom;
                            return [absDisplay subAtomForIndexType:index.subIndexType];
                        } else {
                            NSLog(@"No ABS at index: %lu", (unsigned long)index.atomIndex);
                            return nil;
                        }
                        break;
                    }
                    case kMTSubIndexTypeInner:{
                        
                        if ([atom isKindOfClass:[MTInnerDisplay class]]) {
                            MTInnerDisplay* inner = (MTInnerDisplay*) atom;
                            return [inner subAtomForIndexType:index.subIndexType];
                        } else {
                            NSLog(@"No Inner list at index: %lu", (unsigned long)index.atomIndex);
                        }
                        break;
                    }
                    case kMTSubIndexTypeSubscript:
                    case kMTSubIndexTypeSuperscript:{
                        assert(false);  // Can't happen
                        break;
                    }
                        // We found the right subatom
                        break;
                }
            }
        }
        return nil;
    }
    return nil;
}

- (MTDisplay*) retrieveDisplayForIndex:(MTMathListIndex*) index
{
    // Inside the range
    if (index.subIndexType == kMTSubIndexTypeSuperscript || index.subIndexType == kMTSubIndexTypeSubscript || index.subIndexType == kMTSubIndexTypeBeforeSubscript) {
        for (MTDisplay* atom in self.subDisplays) {
            
            if ([atom isKindOfClass:[MTMathListDisplay class]]) {
                MTMathListDisplay* lineAtom = (MTMathListDisplay*) atom;
                if (index.atomIndex == lineAtom.index) {
                    // this is the right character for the sub/superscript
                    // Check that it's type matches the index
                    if (((lineAtom.type == kMTLinePositionSubscript && index.subIndexType == kMTSubIndexTypeSubscript)
                         || (lineAtom.type == kMTLinePositionSuperscript && index.subIndexType == kMTSubIndexTypeSuperscript) || (lineAtom.type == kMTLinePositionBeforeSubscript && index.subIndexType == kMTSubIndexTypeBeforeSubscript))) {
                        return lineAtom;
                    }
                }
            }
            else if([atom isKindOfClass:[MTLargeOpLimitsDisplay class]]){
                
                MTLargeOpLimitsDisplay* lineAtom1 = (MTLargeOpLimitsDisplay*) atom;
                if(lineAtom1.upperLimit.index == index.atomIndex || lineAtom1.lowerLimit.index == index.atomIndex){
                    
                    if (lineAtom1.upperLimit.type == kMTLinePositionSuperscript && index.subIndexType == kMTSubIndexTypeSuperscript) {
                        return lineAtom1;
                    }
                    
                    else if(lineAtom1.lowerLimit.type == kMTLinePositionSubscript && index.subIndexType == kMTSubIndexTypeSubscript){
                        return lineAtom1;
                    }
                }
            }
        }
    }
    for (MTDisplay* atom in self.subDisplays) {
        //if (![atom isKindOfClass:[MTMathListDisplay class]] && NSLocationInRange(index.atomIndex, atom.range)) {
        if (NSLocationInRange(index.atomIndex, atom.range)) {
            // not a subscript/superscript and
            // jackpot, the index is in the range of this atom.
            switch (index.subIndexType) {
                case kMTSubIndexTypeNone:
                case kMTSubIndexTypeNucleus:
                    return atom;
                    
                case kMTSubIndexTypeDegree:
                case kMTSubIndexTypeRadicand:
                    if ([atom isKindOfClass:[MTRadicalDisplay class]]) {
                        MTRadicalDisplay *radical = (MTRadicalDisplay *) atom;
                        if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                            return atom;
                        }
                        return [radical subAtomForIndexType:index.subIndexType];
                    } else {
                        NSLog(@"No radical at index: %lu", (unsigned long)index.atomIndex);
                        return nil;
                    }
                case kMTSubIndexTypeExponent:
                case kMTSubIndexTypeExpSubscript:
                case kMTSubIndexTypeExpSuperscript:
                case kMTSubIndexTypeExpBeforeSubscript :
                    if ([atom isKindOfClass:[MTExponentDisplay class]]) {
                        MTExponentDisplay *exponent = (MTExponentDisplay *) atom;
                        if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                            return atom;
                        }
                        return [exponent subAtomForIndexType:index.subIndexType];
                    } else {
                        NSLog(@"No exponent display at index: %lu", (unsigned long)index.atomIndex);
                        return nil;
                    }
                    
                case kMTSubIndexTypeNumerator:
                case kMTSubIndexTypeDenominator:
                case kMTSubIndexTypeWhole:
                    if ([atom isKindOfClass:[MTFractionDisplay class]]) {
                        MTFractionDisplay* frac = (MTFractionDisplay*) atom;
                        if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                            return atom;
                        }
                        return [frac subAtomForIndexType:index.subIndexType];
                    } else {
                        NSLog(@"No fraction at index: %lu", (unsigned long)index.atomIndex);
                        return nil;
                    }
                    
                case kMTSubIndexTypeLeftOperand:
                case kMTSubIndexTypeRightOperand:{
                    
                    if ([atom isKindOfClass:[MTOrderedPairDisplay class]]) {
                        MTOrderedPairDisplay *pair = (MTOrderedPairDisplay*)atom;
                        if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                            return atom;
                        }
                        return [pair subAtomForIndexType:index.subIndexType];
                    } else {
                        NSLog(@"No pair at index: %lu", (unsigned long)index.atomIndex);
                        return nil;
                    }
                    break;
                }
                case kMTSubIndexTypeRow0Col0:
                case kMTSubIndexTypeRow0Col1:
                case kMTSubIndexTypeRow1Col0:
                case kMTSubIndexTypeRow1Col1:{
                    
                    if ([atom isKindOfClass:[MTBinomialMatrixDisplay class]]) {
                        MTBinomialMatrixDisplay* matrix = (MTBinomialMatrixDisplay*)atom;
                        if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                            return atom;
                        }
                        return [matrix subAtomForIndexType:index.subIndexType];
                    } else {
                        NSLog(@"No matrix at index: %lu", (unsigned long)index.atomIndex);
                        return nil;
                    }
                    break;
                }
                case kMTSubIndexTypeOverbar:{
                    if ([atom isKindOfClass:[MTAccentDisplay class]]) {
                        MTAccentDisplay *accent = (MTAccentDisplay *) atom;
                        if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                            return atom;
                        }
                        return [accent subAtomForIndexType:index.subIndexType];
                    } else {
                        NSLog(@"No accent at index: %lu", (unsigned long)index.atomIndex);
                        return nil;
                    }
                    break;
                }
                case kMTSubIndexTypeLargeOp:
                case kMTSubIndexTypeLargeOpValueHolder:{
                    if ([atom isKindOfClass:[MTLargeOpLimitsDisplay class]]) {
                        MTLargeOpLimitsDisplay *largeOp = (MTLargeOpLimitsDisplay *) atom;
                        if(largeOp.holder){
                            if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                                return atom;
                            }
                            return [largeOp subAtomForIndexType:index.subIndexType];
                        }
                    }else if([atom isKindOfClass:[MTGlyphDisplay class]]){
                        return atom;
                    }
                    else {
                        NSLog(@"No Large Op at index: %lu", (unsigned long)index.atomIndex);
                        return nil;
                    }
                    break;
                }
                case kMTSubIndexTypeAbsValue:{
                    if ([atom isKindOfClass:[MTAbsoluteValueDisplay class]]) {
                        MTAbsoluteValueDisplay *absDisplay = (MTAbsoluteValueDisplay *) atom;
                        if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                            return atom;
                        }
                        return [absDisplay subAtomForIndexType:index.subIndexType];
                    } else {
                        NSLog(@"No ABS at index: %lu", (unsigned long)index.atomIndex);
                        return nil;
                    }
                    break;
                }
                case kMTSubIndexTypeInner:{
                    
                    if ([atom isKindOfClass:[MTInnerDisplay class]]) {
                        MTInnerDisplay* inner = (MTInnerDisplay*) atom;
                        if(index.subIndex.subIndexType == kMTSubIndexTypeNone){
                            return atom;
                        }
                        return [inner subAtomForIndexType:index.subIndexType];
                    } else {
                        NSLog(@"No Inner list at index: %lu", (unsigned long)index.atomIndex);
                    }
                    break;
                }
                case kMTSubIndexTypeSubscript:
                case kMTSubIndexTypeSuperscript:{
                    assert(false);  // Can't happen
                    break;
                }
                    // We found the right subatom
                    break;
            }
        }
    }
    return nil;
}


- (CGPoint)caretPositionForIndex:(MTMathListIndex *)index
{
    CGPoint position = kInvalidPosition;
    if (!index) {
        return kInvalidPosition;
    }
    
    if (index.atomIndex == NSMaxRange(self.range)) {
        // Special case the edge of the range
        if(self.subDisplays.count > 0){
            position = CGPointMake([self.subDisplays objectAtIndex:index.atomIndex-1].position.x+[self.subDisplays objectAtIndex:index.atomIndex-1].width, [self.subDisplays objectAtIndex:index.atomIndex-1].position.y);
        } else{
            position = CGPointMake(self.width, 0);
        }

    } else if (NSLocationInRange(index.atomIndex, self.range)) {
        MTDisplay* atom = [self subAtomForIndex:index];
        if (index.subIndexType == kMTSubIndexTypeNucleus) {
            NSUInteger nucleusPosition = index.atomIndex + index.subIndex.atomIndex;
            position = [atom caretPositionForIndex:[MTMathListIndex level0Index:nucleusPosition]];
        } else if (index.subIndexType == kMTSubIndexTypeNone) {
            position = [atom caretPositionForIndex:index];
        } else {
            // recurse
            position = [atom caretPositionForIndex:index.subIndex];
        }
    } else {
        // outside the range
        return kInvalidPosition;
    }
    
    if (CGPointEqualToPoint(position, kInvalidPosition)) {
        // we didn't find the position
        return position;
    }
    
    // convert bounds from our coordinate system before returning
    position.x += self.position.x;
    position.y += self.position.y - self.shiftBottom;
    return position;
}


- (void)highlightCharacterAtIndex:(MTMathListIndex *)index color:(UIColor *)color
{
    if (!index) {
        return;
    }
    if (NSLocationInRange(index.atomIndex, self.range)) {
        MTDisplay* atom = [self subAtomForIndex:index];
        if (index.subIndexType == kMTSubIndexTypeNucleus || index.subIndexType == kMTSubIndexTypeNone) {
            [atom highlightCharacterAtIndex:index color:color];
        } else {
            // recurse
            [atom highlightCharacterAtIndex:index.subIndex color:color];
        }
    }
}

- (void)highlightWithColor:(UIColor *)color
{
    for (MTDisplay* atom in self.subDisplays) {
        [atom highlightWithColor:color];
    }
}

@end
