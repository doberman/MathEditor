//
//  MTMathList+Editing.m
//
//  Created by Kostub Deshmukh on 9/5/13.
//  Copyright (C) 2013 MathChat
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTMathList+Editing.h"

#pragma mark - MTMathList

@implementation MTMathList (Editing)

- (void)insertAtom:(MTMathAtom *)atom atListIndex:(MTMathListIndex *)index
{
    if (index.atomIndex > self.atoms.count) {
        @throw [NSException exceptionWithName:NSRangeException
                                       reason:[NSString stringWithFormat:@"Index %lu is out of bounds for list of size %lu", (unsigned long)index.atomIndex, (unsigned long)self.atoms.count]
                                     userInfo:nil];
    }
    
    switch (index.subIndexType) {
        case kMTSubIndexTypeNone:
            [self insertAtom:atom atIndex:index.atomIndex];
            break;
            
        case kMTSubIndexTypeNucleus: {
            MTMathAtom* currentAtom = [self.atoms objectAtIndex:index.atomIndex];
            NSAssert(currentAtom.subScript || currentAtom.superScript, @"Nuclear fusion is not supported if there are no subscripts or superscripts.");
            NSAssert(!atom.subScript && !atom.superScript, @"Cannot fuse with an atom that already has a subscript or a superscript");
            
            atom.subScript = currentAtom.subScript;
            atom.superScript = currentAtom.superScript;
            currentAtom.subScript = nil;
            currentAtom.superScript = nil;
            [self insertAtom:atom atIndex:index.atomIndex + index.subIndex.atomIndex];
            break;
        }
            
        case kMTSubIndexTypeDegree:
        case kMTSubIndexTypeRadicand: {
            MTRadical *radical = [self.atoms objectAtIndex:index.atomIndex];
            if (!radical || radical.type != kMTMathAtomRadical) {
                // Not radical, quit
                NSAssert(false, @"No radical found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeDegree) {
                [radical.degree insertAtom:atom atListIndex:index.subIndex];
            } else {
                [radical.radicand insertAtom:atom atListIndex:index.subIndex];
            }
            break;
        }
        case kMTSubIndexTypeExponent:
        case kMTSubIndexTypeExpSuperscript:
        case kMTSubIndexTypeExpSubscript:
        case kMTSubIndexTypeExpBeforeSubscript:{
            MTExponent *exponent = [self.atoms objectAtIndex:index.atomIndex];
            if (!exponent || exponent.type != kMTMathAtomExponentBase) {
                // Not exponent, quit
                NSAssert(false, @"No exponent found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeExpSuperscript && exponent.isSuperScriptTypePrime == false) {
                [exponent.expSuperScript insertAtom:atom atListIndex:index.subIndex];
            }
            else if (index.subIndexType == kMTSubIndexTypeExpSubscript) {
                [exponent.expSubScript insertAtom:atom atListIndex:index.subIndex];
            }
            else if (index.subIndexType == kMTSubIndexTypeExpBeforeSubscript) {
                [exponent.prefixedSubScript insertAtom:atom atListIndex:index.subIndex];
            }
            else if (index.subIndexType == kMTSubIndexTypeExponent){
                [exponent.exponent insertAtom:atom atListIndex:index.subIndex];
            }
            break;
        }
   
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeNumerator:
        case kMTSubIndexTypeWhole: {
            MTFraction* frac = [self.atoms objectAtIndex:index.atomIndex];
            if (!frac || frac.type != kMTMathAtomFraction) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeWhole) {
                [frac.whole insertAtom:atom atListIndex:index.subIndex];
            } else if (index.subIndexType == kMTSubIndexTypeNumerator) {
                [frac.numerator insertAtom:atom atListIndex:index.subIndex];
            } else {
                [frac.denominator insertAtom:atom atListIndex:index.subIndex];
            }
            break;
        }
            
        case kMTSubIndexTypeOverbar: {
            MTAccent* current = [self.atoms objectAtIndex:index.atomIndex];
            //NSAssert(current.innerList, @"No subscript for atom at index %lu", (unsigned long)index.atomIndex);
            [current.innerList insertAtom:atom atListIndex:index.subIndex];
            break;
        }
            
        case kMTSubIndexTypeSubscript: {
            MTMathAtom* current = [self.atoms objectAtIndex:index.atomIndex];
            NSAssert(current.subScript, @"No subscript for atom at index %lu", (unsigned long)index.atomIndex);
            [current.subScript insertAtom:atom atListIndex:index.subIndex];
            break;
        }
            
        case kMTSubIndexTypeSuperscript: {
            MTMathAtom* current = [self.atoms objectAtIndex:index.atomIndex];
            NSAssert(current.superScript, @"No superscript for atom at index %lu", (unsigned long)index.atomIndex);
            [current.superScript insertAtom:atom atListIndex:index.subIndex];
            break;
        }
            
        case kMTSubIndexTypeBeforeSubscript: {
            MTMathAtom* current = [self.atoms objectAtIndex:index.atomIndex];
            NSAssert(current.beforeSubScript, @"No subscript for atom at index %lu", (unsigned long)index.atomIndex);
            [current.beforeSubScript insertAtom:atom atListIndex:index.subIndex];
            break;
        }
        case kMTSubIndexTypeLargeOpValueHolder:
        case kMTSubIndexTypeLargeOp: {
            MTLargeOperator* current = [self.atoms objectAtIndex:index.atomIndex];
            if (index.subIndexType == kMTSubIndexTypeSuperscript) {
                [current.superScript insertAtom:atom atListIndex:index.subIndex];
            } else if(index.subIndexType == kMTSubIndexTypeSubscript){
                [current.subScript insertAtom:atom atListIndex:index.subIndex];
            } else if(index.subIndexType == kMTSubIndexTypeLargeOpValueHolder){
                [current.holder insertAtom:atom atListIndex:index.subIndex];
            }
            break;
        }
            
        case  kMTSubIndexTypeTable: {
            MTMathAtom* current = [self.atoms objectAtIndex:index.atomIndex];
            [current.superScript insertAtom:atom atListIndex:index.subIndex];
            
            break;
        }
        case kMTSubIndexTypeRightOperand:
        case kMTSubIndexTypeLeftOperand:
        {
            MTOrderedPair* pair = [self.atoms objectAtIndex:index.atomIndex];
            if (!pair || pair.type != kMTMathAtomOrderedPair) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeLeftOperand) {
                [pair.leftOperand insertAtom:atom atListIndex:index.subIndex];
            } else {
                [pair.rightOperand insertAtom:atom atListIndex:index.subIndex];
            }
            break;
        }
            
        case  kMTSubIndexTypeRow0Col0:
        case  kMTSubIndexTypeRow0Col1:
        case  kMTSubIndexTypeRow1Col0:
        case  kMTSubIndexTypeRow1Col1:{
            MTBinomialMatrix* matrix = [self.atoms objectAtIndex:index.atomIndex];
            if (!matrix || matrix.type != kMTMathAtomBinomialMatrix) {
                NSAssert(false, @"No matrix found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeRow0Col0) {
                [matrix.row0Col0 insertAtom:atom atListIndex:index.subIndex];
            } else if (index.subIndexType == kMTSubIndexTypeRow0Col1){
                [matrix.row0Col1 insertAtom:atom atListIndex:index.subIndex];
            }else if (index.subIndexType == kMTSubIndexTypeRow1Col0){
                [matrix.row1Col0 insertAtom:atom atListIndex:index.subIndex];
            }else if (index.subIndexType == kMTSubIndexTypeRow1Col1){
                [matrix.row1Col1 insertAtom:atom atListIndex:index.subIndex];
            }
            break;

        }
        case kMTSubIndexTypeAbsValue:
        {
            MTAbsoluteValue* absValue = [self.atoms objectAtIndex:index.atomIndex];
            if (!absValue || absValue.type != kMTMathAtomAbsoluteValue) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeAbsValue) {
                [absValue.absHolder insertAtom:atom atListIndex:index.subIndex];
            }
            break;
        }
        case kMTSubIndexTypeInner:
        {
            MTInner *innerAtom = [self.atoms objectAtIndex:index.atomIndex];
            [innerAtom.innerList insertAtom:atom atListIndex:index.subIndex];
            break;
        }
    }
}

-(void)removeAtomAtListIndex:(MTMathListIndex *)index
{
    if (index.atomIndex >= self.atoms.count) {
        @throw [NSException exceptionWithName:NSRangeException
                                       reason:[NSString stringWithFormat:@"Index %lu is out of bounds for list of size %lu", (unsigned long)index.atomIndex, (unsigned long)self.atoms.count]
                                     userInfo:nil];
    }
    
    switch (index.subIndexType) {
        case kMTSubIndexTypeNone:
            [self removeAtomAtIndex:index.atomIndex];
            break;
            
        case kMTSubIndexTypeNucleus: {
            MTMathAtom* currentAtom = [self.atoms objectAtIndex:index.atomIndex];
            NSAssert(currentAtom.subScript || currentAtom.superScript, @"Nuclear fission is not supported if there are no subscripts or superscripts.");
            MTMathAtom* previous = nil;
            if (index.atomIndex > 0) {
                previous = [self.atoms objectAtIndex:index.atomIndex - 1];
            }
            if (previous && !previous.subScript && !previous.superScript) {
                previous.superScript = currentAtom.superScript;
                previous.subScript = currentAtom.subScript;
                [self removeAtomAtIndex:index.atomIndex];
            } else {
                // no previous atom or the previous atom sucks (has sub/super scripts)
                currentAtom.nucleus = @"";
            }
            break;
        }
            
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeDegree: {
            MTRadical *radical = [self.atoms objectAtIndex:index.atomIndex];
            if (!radical || radical.type != kMTMathAtomRadical) {
                // Not radical, quit
                NSAssert(false, @"No radical found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeDegree) {
                [radical.degree removeAtomAtListIndex:index.subIndex];
            } else {
                [radical.radicand removeAtomAtListIndex:index.subIndex];
            }
            
            break;
        }
        case kMTSubIndexTypeExponent:
        case kMTSubIndexTypeExpSuperscript:
        case kMTSubIndexTypeExpSubscript:
        case kMTSubIndexTypeExpBeforeSubscript:{
            MTExponent *exponent = [self.atoms objectAtIndex:index.atomIndex];
            if (!exponent || exponent.type != kMTMathAtomExponentBase) {
                // Not exponent, quit
                NSAssert(false, @"No exponent kind found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeExpSuperscript) {
                [exponent.expSuperScript removeAtomAtListIndex:index.subIndex];
            }
            else if(index.subIndexType == kMTSubIndexTypeExpSubscript) {
                [exponent.expSubScript removeAtomAtListIndex:index.subIndex];
            }
            else if(index.subIndexType == kMTSubIndexTypeExpBeforeSubscript) {
                [exponent.prefixedSubScript removeAtomAtListIndex:index.subIndex];
            }
            else {
                [exponent.exponent removeAtomAtListIndex:index.subIndex];
            }
            
            break;
        }
    
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeNumerator:
        case kMTSubIndexTypeWhole: {
            MTFraction* frac = [self.atoms objectAtIndex:index.atomIndex];
            if (!frac || frac.type != kMTMathAtomFraction) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeWhole) {
                [frac.whole removeAtomAtListIndex:index.subIndex];
            } else if (index.subIndexType == kMTSubIndexTypeNumerator) {
                [frac.numerator removeAtomAtListIndex:index.subIndex];
            } else {
                [frac.denominator removeAtomAtListIndex:index.subIndex];
            }
            break;
        }
            
        case kMTSubIndexTypeOverbar: {
            MTAccent* current = [self.atoms objectAtIndex:index.atomIndex];
            //NSAssert(current.innerList, @"No subscript for atom at index %lu", (unsigned long)index.atomIndex);
            [current.innerList removeAtomAtListIndex:index.subIndex];
            break;
        }
            
        case kMTSubIndexTypeSubscript: {
            MTMathAtom* current = [self.atoms objectAtIndex:index.atomIndex];
            NSAssert(current.subScript, @"No subscript for atom at index %lu", (unsigned long)index.atomIndex);
            [current.subScript removeAtomAtListIndex:index.subIndex];
            break;
        }
            
        case kMTSubIndexTypeSuperscript: {
            MTMathAtom* current = [self.atoms objectAtIndex:index.atomIndex];
            NSAssert(current.superScript, @"No superscript for atom at index %lu", (unsigned long)index.atomIndex);
            [current.superScript removeAtomAtListIndex:index.subIndex];
            break;
        }
            
        case kMTSubIndexTypeBeforeSubscript: {
            MTMathAtom* current = [self.atoms objectAtIndex:index.atomIndex];
            NSAssert(current.beforeSubScript, @"No subscript for atom at index %lu", (unsigned long)index.atomIndex);
            [current.beforeSubScript removeAtomAtListIndex:index.subIndex];
            break;
        }

        case kMTSubIndexTypeLargeOpValueHolder:
        case  kMTSubIndexTypeLargeOp:{
            MTLargeOperator* current = [self.atoms objectAtIndex:index.atomIndex];
            if (index.subIndexType == kMTSubIndexTypeSuperscript) {
                [current.superScript removeAtomAtListIndex:index.subIndex];
            } else if (index.subIndexType == kMTSubIndexTypeSubscript){
                [current.subScript removeAtomAtListIndex:index.subIndex];
            } else if(index.subIndexType == kMTSubIndexTypeLargeOpValueHolder){
                [current.holder removeAtomAtListIndex:index.subIndex];
            }
            break;
        }
        case kMTSubIndexTypeRightOperand:
        case kMTSubIndexTypeLeftOperand: {
            MTOrderedPair* pair = [self.atoms objectAtIndex:index.atomIndex];
            if (!pair || pair.type != kMTMathAtomOrderedPair) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeLeftOperand) {
                [pair.leftOperand removeAtomAtListIndex:index.subIndex];
            } else {
                [pair.rightOperand removeAtomAtListIndex:index.subIndex];
            }
            break;
        }
        case  kMTSubIndexTypeRow0Col0:
        case  kMTSubIndexTypeRow0Col1:
        case  kMTSubIndexTypeRow1Col0:
        case  kMTSubIndexTypeRow1Col1:{
            MTBinomialMatrix* matrix = [self.atoms objectAtIndex:index.atomIndex];
            if (!matrix || matrix.type != kMTMathAtomBinomialMatrix) {
                NSAssert(false, @"No matrix found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeRow0Col0) {
                [matrix.row0Col0 removeAtomAtListIndex:index.subIndex];
            } else if (index.subIndexType == kMTSubIndexTypeRow0Col1){
                [matrix.row0Col1 removeAtomAtListIndex:index.subIndex];
            }else if (index.subIndexType == kMTSubIndexTypeRow1Col0){
                [matrix.row1Col0 removeAtomAtListIndex:index.subIndex];
            }else if (index.subIndexType == kMTSubIndexTypeRow1Col1){
                [matrix.row1Col1 removeAtomAtListIndex:index.subIndex];
            }
            
            break;
            
        }
        case kMTSubIndexTypeAbsValue: {
            MTAbsoluteValue* absValue = [self.atoms objectAtIndex:index.atomIndex];
            if (!absValue || absValue.type != kMTMathAtomAbsoluteValue) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeAbsValue) {
                [absValue.absHolder removeAtomAtListIndex:index.subIndex];
            }
            break;
        }
        case kMTSubIndexTypeInner: {
            MTInner* innerValue = [self.atoms objectAtIndex:index.atomIndex];
            if (!innerValue || innerValue.type != kMTMathAtomInner) {
                NSAssert(false, @"No Inner found at index %lu", (unsigned long)index.atomIndex);
                return;
            }
            if (index.subIndexType == kMTSubIndexTypeInner) {
                [innerValue.innerList removeAtomAtListIndex:index.subIndex];
            }
            break;
        }
    
            
    }
}

- (void) removeAtomsInListIndexRange:(MTMathListRange*) range
{
    MTMathListIndex* start = range.start;
    
    switch (start.subIndexType) {
        case kMTSubIndexTypeNone:
            [self removeAtomsInRange:NSMakeRange(start.atomIndex, range.length)];
            break;
            
        case kMTSubIndexTypeNucleus:
            NSAssert(false, @"Nuclear fission is not supported");
            break;
            
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeDegree: {
            MTRadical *radical = [self.atoms objectAtIndex:start.atomIndex];
            if (!radical || radical.type != kMTMathAtomRadical) {
                // Not radical, quit
                NSAssert(false, @"No radical found at index %lu", (unsigned long)start.atomIndex);
                return;
            }
            if (start.subIndexType == kMTSubIndexTypeDegree) {
                [radical.degree removeAtomsInListIndexRange:range.subIndexRange];
            } else {
                [radical.radicand removeAtomsInListIndexRange:range.subIndexRange];
            }
            break;
        }
        case kMTSubIndexTypeExponent:
        case kMTSubIndexTypeExpSuperscript:
        case kMTSubIndexTypeExpSubscript:
        case kMTSubIndexTypeExpBeforeSubscript:{
            MTExponent *exponent = [self.atoms objectAtIndex:start.atomIndex];
            if (!exponent || exponent.type != kMTMathAtomExponentBase) {
                // Not exponent, quit
                NSAssert(false, @"No exponent found at index %lu", (unsigned long)start.atomIndex);
                return;
            }
            if (start.subIndexType == kMTSubIndexTypeExpSuperscript) {
                [exponent.expSuperScript removeAtomsInListIndexRange:range.subIndexRange];
            }
            else if (start.subIndexType == kMTSubIndexTypeExpSubscript) {
                [exponent.expSubScript removeAtomsInListIndexRange:range.subIndexRange];
            }
            else if (start.subIndexType == kMTSubIndexTypeExpBeforeSubscript) {
                [exponent.prefixedSubScript removeAtomsInListIndexRange:range.subIndexRange];
            }
            else {
                [exponent.exponent removeAtomsInListIndexRange:range.subIndexRange];
            }
            break;
        }
    
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeNumerator: {
            MTFraction* frac = [self.atoms objectAtIndex:start.atomIndex];
            if (!frac || frac.type != kMTMathAtomFraction) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)start.atomIndex);
                return;
            }
            if (start.subIndexType == kMTSubIndexTypeNumerator) {
                [frac.numerator removeAtomsInListIndexRange:range.subIndexRange];
            } else {
                [frac.denominator removeAtomsInListIndexRange:range.subIndexRange];
            }
            break;
        }
            
        case kMTSubIndexTypeSubscript: {
            MTMathAtom* current = [self.atoms objectAtIndex:start.atomIndex];
            NSAssert(current.subScript, @"No subscript for atom at index %lu", (unsigned long)start.atomIndex);
            [current.subScript removeAtomsInListIndexRange:range.subIndexRange];
            break;
        }
            
        case kMTSubIndexTypeSuperscript: {
            MTMathAtom* current = [self.atoms objectAtIndex:start.atomIndex];
            NSAssert(current.superScript, @"No superscript for atom at index %lu", (unsigned long)start.atomIndex);
            [current.superScript removeAtomsInListIndexRange:range.subIndexRange];
            break;
        }
        case kMTSubIndexTypeRightOperand:
        case kMTSubIndexTypeLeftOperand: {
            MTOrderedPair* pair = [self.atoms objectAtIndex:start.atomIndex];
            if (!pair || pair.type != kMTMathAtomOrderedPair) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)start.atomIndex);
                return;
            }
            if (start.subIndexType == kMTSubIndexTypeLeftOperand) {
                [pair.leftOperand removeAtomsInListIndexRange:range.subIndexRange];
            } else {
                [pair.rightOperand removeAtomsInListIndexRange:range.subIndexRange];
            }
            break;
        }
        case kMTSubIndexTypeLargeOp:
        case kMTSubIndexTypeLargeOpValueHolder: {
            MTLargeOperator* largeOp = [self.atoms objectAtIndex:start.atomIndex];
            if (!largeOp || largeOp.type != kMTMathAtomLargeOperator) {
                NSAssert(false, @"No largeOp found at index %lu", (unsigned long)start.atomIndex);
                return;
            }
            if (start.subIndexType == kMTSubIndexTypeLargeOpValueHolder) {
                [largeOp.holder removeAtomsInListIndexRange:range.subIndexRange];
            } 
            break;
        }
        case  kMTSubIndexTypeRow0Col0:
        case  kMTSubIndexTypeRow0Col1:
        case  kMTSubIndexTypeRow1Col0:
        case  kMTSubIndexTypeRow1Col1:{
            MTBinomialMatrix* matrix = [self.atoms objectAtIndex:start.atomIndex];
            if (!matrix || matrix.type != kMTMathAtomBinomialMatrix) {
                NSAssert(false, @"No matrix found at index %lu", (unsigned long)start.atomIndex);
                return;
            }
            if (start.subIndexType == kMTSubIndexTypeRow0Col0) {
                [matrix.row0Col0 removeAtomsInListIndexRange:range.subIndexRange];
            } else if (start.subIndexType == kMTSubIndexTypeRow0Col1){
                [matrix.row0Col1 removeAtomsInListIndexRange:range.subIndexRange];
            }else if (start.subIndexType == kMTSubIndexTypeRow1Col0){
                [matrix.row1Col0 removeAtomsInListIndexRange:range.subIndexRange];
            }else if (start.subIndexType == kMTSubIndexTypeRow1Col1){
                [matrix.row1Col1 removeAtomsInListIndexRange:range.subIndexRange];
            }
            
            break;
            
        }
        case kMTSubIndexTypeAbsValue: {
            MTAbsoluteValue* absValue = [self.atoms objectAtIndex:start.atomIndex];
            if (!absValue || absValue.type != kMTMathAtomAbsoluteValue) {
                NSAssert(false, @"No fraction found at index %lu", (unsigned long)start.atomIndex);
                return;
            }
            if (start.subIndexType == kMTSubIndexTypeAbsValue) {
                [absValue.absHolder removeAtomsInListIndexRange:range.subIndexRange];
            }
            break;
        }
        case kMTSubIndexTypeInner: {
            MTInner* innerValue = [self.atoms objectAtIndex:start.atomIndex];
            if (!innerValue || innerValue.type != kMTMathAtomInner) {
                NSAssert(false, @"No Inner found at index %lu", (unsigned long)start.atomIndex);
                return;
            }
            if (start.subIndexType == kMTSubIndexTypeInner) {
                [innerValue.innerList removeAtomsInListIndexRange:range.subIndexRange];
            }
            break;
        }
    
    }
}

- (MTMathAtom *)atomAtListIndex:(MTMathListIndex *)index
{
    if (index == nil) {
        return nil;
    }
    
    if (index.atomIndex >= self.atoms.count) {
        return nil;
    }
    
    MTMathAtom* atom = self.atoms[index.atomIndex];
    
    switch (index.subIndexType) {
        case kMTSubIndexTypeNone:
        case kMTSubIndexTypeNucleus:
            return atom;
            
        case kMTSubIndexTypeOverbar:
            if (atom.type == kMTMathAtomAccent) {
                MTAccent *accent = (MTAccent *) atom;
                if (index.subIndexType == kMTSubIndexTypeOverbar) {
                    return [accent.innerList atomAtListIndex:index.subIndex];
                }
            } else {
                // No overbar at this index
                return nil;
            }
            
        case kMTSubIndexTypeLargeOpValueHolder:
        case kMTSubIndexTypeLargeOp:
            if (atom.type == kMTMathAtomLargeOperator) {
                MTLargeOperator *largeOp = (MTLargeOperator *) atom;
                if (index.subIndexType == kMTSubIndexTypeSuperscript) {
                    return [largeOp.superScript atomAtListIndex:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeSubscript){
                    return [largeOp.subScript atomAtListIndex:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeLargeOpValueHolder){
                    return [largeOp.holder atomAtListIndex:index.subIndex];
                }else{
                    return largeOp;
                }
            } else {
                // No radical at this index
                return nil;
            }
        case kMTSubIndexTypeInner: {
            MTInner *inner = (MTInner *) atom;
            return [inner.innerList atomAtListIndex:index.subIndex];
        }
        case kMTSubIndexTypeSubscript:
            return [atom.subScript atomAtListIndex:index.subIndex];
            
        case kMTSubIndexTypeSuperscript:
            return [atom.superScript atomAtListIndex:index.subIndex];
            
        case kMTSubIndexTypeBeforeSubscript:
            return [atom.beforeSubScript atomAtListIndex:index.subIndex];
            
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeDegree: {
            if (atom.type == kMTMathAtomRadical) {
                MTRadical *radical = (MTRadical *) atom;
                if (index.subIndexType == kMTSubIndexTypeDegree) {
                    return [radical.degree atomAtListIndex:index.subIndex];
                } else {
                    return [radical.radicand atomAtListIndex:index.subIndex];
                }
            } else {
                // No radical at this index
                return nil;
            }
        }
        case kMTSubIndexTypeExponent:
        case kMTSubIndexTypeExpBeforeSubscript:
        case kMTSubIndexTypeExpSubscript:
        case kMTSubIndexTypeExpSuperscript:
        {
            if (atom.type == kMTMathAtomExponentBase) {
                MTExponent *exponent = (MTExponent *) atom;
                if (index.subIndexType == kMTSubIndexTypeExpSuperscript) {
                    return [exponent.expSuperScript atomAtListIndex:index.subIndex];
                }
                else if (index.subIndexType == kMTSubIndexTypeExpSubscript) {
                    return [exponent.expSubScript atomAtListIndex:index.subIndex];
                }
                else if (index.subIndexType == kMTSubIndexTypeExpBeforeSubscript) {
                    return [exponent.prefixedSubScript atomAtListIndex:index.subIndex];
                }
                else {
                    return [exponent.exponent atomAtListIndex:index.subIndex];
                }
            } else {
                // No exponent at this index
                return nil;
            }
        }
            
        case kMTSubIndexTypeNumerator:
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeWhole:
        {
            if (atom.type == kMTMathAtomFraction) {
                MTFraction* frac = (MTFraction*) atom;
                if (index.subIndexType == kMTSubIndexTypeWhole) {
                    return [frac.whole atomAtListIndex:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeDenominator) {
                    return [frac.denominator atomAtListIndex:index.subIndex];
                } else {
                    return [frac.numerator atomAtListIndex:index.subIndex];
                }
                
            } else {
                // No fraction at this index.
                return nil;
            }
        }
            
        case kMTSubIndexTypeTable:{
            if (atom.type == kMTMathAtomTable) {
                MTInner *inner = (MTInner *) atom;
                if (index.subIndexType == kMTSubIndexTypeTable) {
                    return [inner.innerList atomAtListIndex:index.subIndex];
                }
            } else {
                // No overbar at this index
                return nil;
            }
        }
        case kMTSubIndexTypeLeftOperand:
        case kMTSubIndexTypeRightOperand:
        {
            if (atom.type == kMTMathAtomOrderedPair) {
                MTOrderedPair* pair = (MTOrderedPair*) atom;
                if (index.subIndexType == kMTSubIndexTypeRightOperand) {
                    return [pair.rightOperand atomAtListIndex:index.subIndex];
                } else {
                    return [pair.leftOperand atomAtListIndex:index.subIndex];
                }
                
            } else {
                // No pair at this index.
                return nil;
            }
        }
            
        case kMTSubIndexTypeRow0Col0:
        case kMTSubIndexTypeRow0Col1:
        case kMTSubIndexTypeRow1Col0:
        case kMTSubIndexTypeRow1Col1:
        {
            if (atom.type == kMTMathAtomBinomialMatrix) {
                MTBinomialMatrix* matrix = (MTBinomialMatrix*) atom;
                if (index.subIndexType == kMTSubIndexTypeRow0Col0) {
                    return [matrix.row0Col0 atomAtListIndex:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeRow0Col1){
                    return [matrix.row0Col1 atomAtListIndex:index.subIndex];
                }else if (index.subIndexType == kMTSubIndexTypeRow1Col0){
                    return [matrix.row1Col0 atomAtListIndex:index.subIndex];
                }else if (index.subIndexType == kMTSubIndexTypeRow1Col1){
                    return [matrix.row1Col1 atomAtListIndex:index.subIndex];
                }
                
            }
            else {
                return nil;
            }
        }
            
        case kMTSubIndexTypeAbsValue:
        {
            if (atom.type == kMTMathAtomAbsoluteValue) {
                MTAbsoluteValue *absValue = (MTAbsoluteValue*) atom;
                if (index.subIndexType == kMTSubIndexTypeAbsValue) {
                    return [absValue.absHolder atomAtListIndex:index.subIndex];
                }
                
            } else {
                // No pair at this index.
                return nil;
            }
        }
            
    }
    return nil;
}

- (MTMathAtom *)retrieveAtomAtListIndex:(MTMathListIndex *)index
{
    if (index == nil) {
        return nil;
    }
    
    if (index.atomIndex >= self.atoms.count) {
        return nil;
    }
    
    MTMathAtom* atom =  atom = self.atoms[index.atomIndex];
    switch (index.subIndexType) {
        case kMTSubIndexTypeNone:
        case kMTSubIndexTypeNucleus:
            return nil;
            
        case kMTSubIndexTypeOverbar:
            if (atom.type == kMTMathAtomAccent) {
                MTAccent *accent = (MTAccent *) atom;
                if (index.subIndexType == kMTSubIndexTypeOverbar) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return accent;
                    }
                    return [accent.innerList retrieveAtomAtListIndex:index.subIndex];
                }
            } else {
                // No overbar at this index
                return nil;
            }
        case kMTSubIndexTypeLargeOpValueHolder:
        case kMTSubIndexTypeLargeOp:
            if (atom.type == kMTMathAtomLargeOperator) {
                MTLargeOperator *largeOp = (MTLargeOperator *) atom;
                if (index.subIndexType == kMTSubIndexTypeSuperscript) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return largeOp;
                    }
                    return [largeOp.superScript retrieveAtomAtListIndex:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeSubscript){
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return largeOp;
                    }
                    return [largeOp.subScript retrieveAtomAtListIndex:index.subIndex];
                } else if(index.subIndexType == kMTSubIndexTypeLargeOpValueHolder){
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return largeOp;
                    }
                    return [largeOp.holder retrieveAtomAtListIndex:index.subIndex];
                } else {
                    return largeOp;
                }
            } else {
                // No radical at this index
                return nil;
            }
            
        case kMTSubIndexTypeSubscript:{
            if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                return atom;
            }
            return [atom.subScript retrieveAtomAtListIndex:index.subIndex];
        }
            
        case kMTSubIndexTypeSuperscript:{
            if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                return atom;
            }
            return [atom.superScript retrieveAtomAtListIndex:index.subIndex];
        }
            
        case kMTSubIndexTypeBeforeSubscript:{
            if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                return atom;
            }
            return [atom.beforeSubScript retrieveAtomAtListIndex:index.subIndex];
        }
            
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeDegree: {
            if (atom.type == kMTMathAtomRadical) {
                MTRadical *radical = (MTRadical *) atom;
                if (index.subIndexType == kMTSubIndexTypeDegree) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return radical;
                    }
                    return [radical.degree retrieveAtomAtListIndex:index.subIndex];
                } else {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return radical;
                    }
                    return [radical.radicand retrieveAtomAtListIndex:index.subIndex];
                }
            } else {
                // No radical at this index
                return nil;
            }
        }
        case kMTSubIndexTypeExponent:
        case kMTSubIndexTypeExpBeforeSubscript:
        case kMTSubIndexTypeExpSubscript:
        case kMTSubIndexTypeExpSuperscript:
        {
            if (atom.type == kMTMathAtomExponentBase) {
                MTExponent *exponent = (MTExponent *) atom;
                if (index.subIndexType == kMTSubIndexTypeExpSuperscript) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return exponent;
                    }
                    return [exponent.expSuperScript retrieveAtomAtListIndex:index.subIndex];
                }
                else if (index.subIndexType == kMTSubIndexTypeExpSubscript) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return exponent;
                    }
                    return [exponent.expSubScript retrieveAtomAtListIndex:index.subIndex];
                }
                else if (index.subIndexType == kMTSubIndexTypeExpBeforeSubscript) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return exponent;
                    }
                    return [exponent.prefixedSubScript retrieveAtomAtListIndex:index.subIndex];
                }
                else {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return exponent;
                    }
                    return [exponent.exponent retrieveAtomAtListIndex:index.subIndex];
                }
            } else {
                // No exponent at this index
                return nil;
            }
        }
            
        case kMTSubIndexTypeNumerator:
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeWhole:
        {
            if (atom.type == kMTMathAtomFraction) {
                MTFraction* frac = (MTFraction*) atom;
                if (index.subIndexType == kMTSubIndexTypeWhole) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return frac;
                    }
                    return [frac.whole retrieveAtomAtListIndex:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeDenominator) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return frac;
                    }
                    return [frac.denominator retrieveAtomAtListIndex:index.subIndex];
                } else {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return frac;
                    }
                    return [frac.numerator retrieveAtomAtListIndex:index.subIndex];
                }
                
            } else {
                // No fraction at this index.
                return nil;
            }
        }
            
        case kMTSubIndexTypeTable:{
            if (atom.type == kMTMathAtomTable) {
                MTInner *inner = (MTInner *) atom;
                if (index.subIndexType == kMTSubIndexTypeTable) {
                    return [inner.innerList atomAtListIndex:index.subIndex];
                }
            } else {
                // No overbar at this index
                return nil;
            }
        }
        case kMTSubIndexTypeLeftOperand:
        case kMTSubIndexTypeRightOperand:
        {
            if (atom.type == kMTMathAtomOrderedPair) {
                MTOrderedPair* pair = (MTOrderedPair*) atom;
                if (index.subIndexType == kMTSubIndexTypeRightOperand) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return atom;
                    }
                    return [pair.rightOperand retrieveAtomAtListIndex:index.subIndex];
                } else {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return atom;
                    }
                    return [pair.leftOperand retrieveAtomAtListIndex:index.subIndex];
                }
                
            } else {
                // No pair at this index.
                return nil;
            }
        }
            
        case kMTSubIndexTypeRow0Col0:
        case kMTSubIndexTypeRow0Col1:
        case kMTSubIndexTypeRow1Col0:
        case kMTSubIndexTypeRow1Col1:
        {
            if (atom.type == kMTMathAtomBinomialMatrix) {
                MTBinomialMatrix* matrix = (MTBinomialMatrix*) atom;
                if (index.subIndexType == kMTSubIndexTypeRow0Col0) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return matrix;
                    }
                    return [matrix.row0Col0 retrieveAtomAtListIndex:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeRow0Col1){
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return matrix;
                    }
                    return [matrix.row0Col1 retrieveAtomAtListIndex:index.subIndex];
                }else if (index.subIndexType == kMTSubIndexTypeRow1Col0){
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return matrix;
                    }
                    return [matrix.row1Col0 retrieveAtomAtListIndex:index.subIndex];
                }else if (index.subIndexType == kMTSubIndexTypeRow1Col1){
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return matrix;
                    }
                    return [matrix.row1Col1 retrieveAtomAtListIndex:index.subIndex];
                }
                
            }
            else {
                return nil;
            }
        }
            
        case kMTSubIndexTypeAbsValue:
        {
            if (atom.type == kMTMathAtomAbsoluteValue) {
                MTAbsoluteValue *absValue = (MTAbsoluteValue*) atom;
                if (index.subIndexType == kMTSubIndexTypeAbsValue) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return absValue;
                    }
                    return [absValue.absHolder retrieveAtomAtListIndex:index.subIndex];
                }
            } else {
                return nil;
            }
        }
        case kMTSubIndexTypeInner:
        {
            if (atom.type == kMTMathAtomInner) {
                MTInner *innerValue = (MTInner*) atom;
                if (index.subIndexType == kMTSubIndexTypeInner) {
                    if(index.subIndex.subIndexType == kMTSubIndexTypeNone) {
                        return innerValue;
                    }
                    return [innerValue.innerList retrieveAtomAtListIndex:index.subIndex];
                }
            } else {
                return nil;
            }
        }
            
        default:
            break;
    }
    return nil;
}

- (MTMathList*)retrieveParentMathListForInner:(MTMathListIndex *)index
{
    if (index == nil) {
        return nil;
    }
    
    if (index.atomIndex >= self.atoms.count) {
        return nil;
    }
    
    MTMathAtom* atom =  atom = self.atoms[index.atomIndex];
    switch (index.subIndexType){
        case kMTSubIndexTypeNone:
        case kMTSubIndexTypeNucleus:
            return nil;
            
        case kMTSubIndexTypeOverbar:
            if (atom.type == kMTMathAtomAccent) {
                MTAccent *accent = (MTAccent *) atom;
                if (index.subIndexType == kMTSubIndexTypeOverbar) {
                    if([self isFinalInner:index]) {
                        return accent.innerList;
                    }
                    return [accent.innerList retrieveParentMathListForInner:index.subIndex];
                }
            } else {
                // No overbar at this index
                return nil;
            }
        case kMTSubIndexTypeLargeOpValueHolder:
        case kMTSubIndexTypeLargeOp:
            if (atom.type == kMTMathAtomLargeOperator) {
                MTLargeOperator *largeOp = (MTLargeOperator *) atom;
                if (index.subIndexType == kMTSubIndexTypeSuperscript) {
                    if([self isFinalInner:index]) {
                        return largeOp.superScript;
                    }
                    return [largeOp.superScript retrieveParentMathListForInner:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeSubscript){
                    if([self isFinalInner:index]) {
                        return largeOp.subScript;
                    }
                    return [largeOp.subScript retrieveParentMathListForInner:index.subIndex];
                } else if(index.subIndexType == kMTSubIndexTypeLargeOpValueHolder){
                    if([self isFinalInner:index]) {
                        return largeOp.holder;
                    }
                    return [largeOp.holder retrieveParentMathListForInner:index.subIndex];
                } else {
                    return nil;
                }
            } else {
                // No radical at this index
                return nil;
            }
            
        case kMTSubIndexTypeSubscript:{
            if([self isFinalInner:index]) {
                return atom.subScript;
            }
            return [atom.subScript retrieveParentMathListForInner:index.subIndex];
        }
            
        case kMTSubIndexTypeSuperscript:{
            if([self isFinalInner:index]) {
                return atom.superScript;
            }
            return [atom.superScript retrieveParentMathListForInner:index.subIndex];
        }
            
        case kMTSubIndexTypeRadicand:
        case kMTSubIndexTypeDegree: {
            if (atom.type == kMTMathAtomRadical) {
                MTRadical *radical = (MTRadical *) atom;
                if (index.subIndexType == kMTSubIndexTypeDegree) {
                    if([self isFinalInner:index]) {
                        return radical.degree;
                    }
                    return [radical.degree retrieveParentMathListForInner:index.subIndex];
                } else {
                    if([self isFinalInner:index]) {
                        return radical.radicand;
                    }
                    return [radical.radicand retrieveParentMathListForInner:index.subIndex];
                }
            } else {
                // No radical at this index
                return nil;
            }
        }
        case kMTSubIndexTypeExponent:
        case kMTSubIndexTypeExpBeforeSubscript:
        case kMTSubIndexTypeExpSubscript:
        case kMTSubIndexTypeExpSuperscript:
        {
            if (atom.type == kMTMathAtomExponentBase) {
                MTExponent *exponent = (MTExponent *) atom;
                if (index.subIndexType == kMTSubIndexTypeExpSuperscript) {
                    if([self isFinalInner:index]) {
                        return exponent.expSuperScript;
                    }
                    return [exponent.expSuperScript retrieveParentMathListForInner:index.subIndex];
                }
                else if (index.subIndexType == kMTSubIndexTypeExpSubscript) {
                    if([self isFinalInner:index]) {
                        return exponent.expSubScript;
                    }
                    return [exponent.expSubScript retrieveParentMathListForInner:index.subIndex];
                }
                else if (index.subIndexType == kMTSubIndexTypeExpBeforeSubscript) {
                    if([self isFinalInner:index]) {
                        return exponent.prefixedSubScript;
                    }
                    return [exponent.prefixedSubScript retrieveParentMathListForInner:index.subIndex];
                }
                else {
                    if([self isFinalInner:index]) {
                        return exponent.exponent;
                    }
                    return [exponent.exponent retrieveParentMathListForInner:index.subIndex];
                }
            } else {
                // No exponent at this index
                return nil;
            }
        }
            
        case kMTSubIndexTypeNumerator:
        case kMTSubIndexTypeDenominator:
        case kMTSubIndexTypeWhole:
        {
            if (atom.type == kMTMathAtomFraction) {
                MTFraction* frac = (MTFraction*) atom;
                if (index.subIndexType == kMTSubIndexTypeWhole) {
                    if([self isFinalInner:index]) {
                        return frac.whole;
                    }
                    return [frac.whole retrieveParentMathListForInner:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeDenominator) {
                    if([self isFinalInner:index]) {
                        return frac.denominator;
                    }
                    return [frac.denominator retrieveParentMathListForInner:index.subIndex];
                } else {
                    if([self isFinalInner:index]) {
                        return frac.numerator;
                    }
                    return [frac.numerator retrieveParentMathListForInner:index.subIndex];
                }
                
            } else {
                // No fraction at this index.
                return nil;
            }
        }
            
        case kMTSubIndexTypeTable:{
            if (atom.type == kMTMathAtomTable) {
                MTInner *inner = (MTInner *) atom;
                if (index.subIndexType == kMTSubIndexTypeTable) {
                    if([self isFinalInner:index]) {
                        return inner.innerList;
                    }
                    return [inner.innerList retrieveParentMathListForInner:index.subIndex];
                }
            } else {
                // No overbar at this index
                return nil;
            }
        }
        case kMTSubIndexTypeLeftOperand:
        case kMTSubIndexTypeRightOperand:
        {
            if (atom.type == kMTMathAtomOrderedPair) {
                MTOrderedPair* pair = (MTOrderedPair*) atom;
                if (index.subIndexType == kMTSubIndexTypeRightOperand) {
                    if([self isFinalInner:index]) {
                        return pair.rightOperand;
                    }
                    return [pair.rightOperand retrieveParentMathListForInner:index.subIndex];
                } else {
                    if([self isFinalInner:index]) {
                        return pair.leftOperand;
                    }
                    return [pair.leftOperand retrieveParentMathListForInner:index.subIndex];
                }
                
            } else {
                // No pair at this index.
                return nil;
            }
        }
            
        case kMTSubIndexTypeRow0Col0:
        case kMTSubIndexTypeRow0Col1:
        case kMTSubIndexTypeRow1Col0:
        case kMTSubIndexTypeRow1Col1:
        {
            if (atom.type == kMTMathAtomBinomialMatrix) {
                MTBinomialMatrix* matrix = (MTBinomialMatrix*) atom;
                if (index.subIndexType == kMTSubIndexTypeRow0Col0) {
                    if([self isFinalInner:index]) {
                        return matrix.row0Col0;
                    }
                    return [matrix.row0Col0 retrieveParentMathListForInner:index.subIndex];
                } else if (index.subIndexType == kMTSubIndexTypeRow0Col1){
                    if([self isFinalInner:index]) {
                        return matrix.row0Col1;
                    }
                    return [matrix.row0Col1 retrieveParentMathListForInner:index.subIndex];
                }else if (index.subIndexType == kMTSubIndexTypeRow1Col0){
                    if([self isFinalInner:index]) {
                        return matrix.row1Col0;
                    }
                    return [matrix.row1Col0 retrieveParentMathListForInner:index.subIndex];
                }else if (index.subIndexType == kMTSubIndexTypeRow1Col1){
                    if([self isFinalInner:index]) {
                        return matrix.row1Col1;
                    }
                    return [matrix.row1Col1 retrieveParentMathListForInner:index.subIndex];
                }
                
            }
            else {
                return nil;
            }
        }
            
        case kMTSubIndexTypeAbsValue:
        {
            if (atom.type == kMTMathAtomAbsoluteValue) {
                MTAbsoluteValue *absValue = (MTAbsoluteValue*) atom;
                if (index.subIndexType == kMTSubIndexTypeAbsValue) {
                    if([self isFinalInner:index]) {
                        return absValue.absHolder;
                    }
                    return [absValue.absHolder retrieveParentMathListForInner:index.subIndex];
                }
            } else {
                return nil;
            }
        }
        case kMTSubIndexTypeInner:
        {
            if (atom.type == kMTMathAtomInner) {
                MTInner *inner = (MTInner*) atom;
                if (index.subIndexType == kMTSubIndexTypeInner) {
                    if([self isFinalInner:index]) {
                        return inner.innerList;
                    }
                    return [inner.innerList retrieveParentMathListForInner:index.subIndex];
                }
            } else {
                return nil;
            }
        }
            
        default:
            break;
    }
    return nil;
}
- (BOOL)isFinalInner:(MTMathListIndex*)mathListIndex {
    if((mathListIndex.subIndex.subIndexType == kMTSubIndexTypeInner) && (mathListIndex.subIndex.subIndex.subIndexType == kMTSubIndexTypeNone)) {
        return true;
    }
    return false;
}

@end
