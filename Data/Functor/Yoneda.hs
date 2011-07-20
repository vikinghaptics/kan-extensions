{-# LANGUAGE TypeFamilies, CPP, Rank2Types, FlexibleContexts, MultiParamTypeClasses, UndecidableInstances, FlexibleInstances #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Functor.Yoneda
-- Copyright   :  (C) 2011 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  MPTCs, fundeps
--
----------------------------------------------------------------------------

module Data.Functor.Yoneda
  ( Yoneda(..)
  , liftYoneda
  , lowerYoneda
  , maxF, minF, maxM, minM
  ) where

import Control.Applicative
import Control.Monad (MonadPlus(..), liftM)
import Control.Monad.Fix
import Control.Monad.Free.Class
import Control.Monad.Trans.Class
import Control.Comonad
import Control.Comonad.Trans.Class
import Data.Distributive
import Data.Foldable
import Data.Function (on)
import Data.Functor.Plus
import Data.Functor.Bind
import Data.Functor.Adjunction
import Data.Functor.Representable
import Data.Key
-- import Data.Semigroup
import Data.Semigroup.Foldable
import Data.Semigroup.Traversable
import Data.Traversable
import Text.Read hiding (lift)
import Prelude hiding (sequence, lookup, zipWith)

newtype Yoneda f a = Yoneda { runYoneda :: forall b. (a -> b) -> f b } 

liftYoneda :: Functor f => f a -> Yoneda f a 
liftYoneda a = Yoneda (\f -> fmap f a)

lowerYoneda :: Yoneda f a -> f a 
lowerYoneda (Yoneda f) = f id

{-# RULES "lower/lift=id" liftYoneda . lowerYoneda = id #-}
{-# RULES "lift/lower=id" lowerYoneda . liftYoneda = id #-}

instance Functor (Yoneda f) where
  fmap f m = Yoneda (\k -> runYoneda m (k . f))

type instance Key (Yoneda f) = Key f

instance Keyed f => Keyed (Yoneda f) where
  mapWithKey f = liftYoneda . mapWithKey f . lowerYoneda 

instance Apply f => Apply (Yoneda f) where
  Yoneda m <.> Yoneda n = Yoneda (\f -> m (f .) <.> n id)
  
instance Applicative f => Applicative (Yoneda f) where
  pure a = Yoneda (\f -> pure (f a))
  Yoneda m <*> Yoneda n = Yoneda (\f -> m (f .) <*> n id)

instance Zip f => Zip (Yoneda f) where
  zipWith f (Yoneda m) (Yoneda n) = liftYoneda $ zipWith f (m id) (n id)

instance ZipWithKey f => ZipWithKey (Yoneda f) where
  zipWithKey f (Yoneda m) (Yoneda n) = liftYoneda $ zipWithKey f (m id) (n id)

instance Foldable f => Foldable (Yoneda f) where
  foldMap f = foldMap f . lowerYoneda

instance Foldable1 f => Foldable1 (Yoneda f) where
  foldMap1 f = foldMap1 f . lowerYoneda

instance FoldableWithKey f => FoldableWithKey (Yoneda f) where
  foldMapWithKey f = foldMapWithKey f . lowerYoneda

instance FoldableWithKey1 f => FoldableWithKey1 (Yoneda f) where
  foldMapWithKey1 f = foldMapWithKey1 f . lowerYoneda

instance Traversable f => Traversable (Yoneda f) where
  traverse f = fmap liftYoneda . traverse f . lowerYoneda

instance TraversableWithKey f => TraversableWithKey (Yoneda f) where
  traverseWithKey f = fmap liftYoneda . traverseWithKey f . lowerYoneda

instance Traversable1 f => Traversable1 (Yoneda f) where
  traverse1 f = fmap liftYoneda . traverse1 f . lowerYoneda

instance TraversableWithKey1 f => TraversableWithKey1 (Yoneda f) where
  traverseWithKey1 f = fmap liftYoneda . traverseWithKey1 f . lowerYoneda

instance Distributive f => Distributive (Yoneda f) where
  collect f = liftYoneda . collect (lowerYoneda . f)

instance Indexable f => Indexable (Yoneda f) where
  index = index . lowerYoneda

instance Lookup f => Lookup (Yoneda f) where
  lookup i = lookup i . lowerYoneda

instance Representable g => Representable (Yoneda g) where
  tabulate = liftYoneda . tabulate

instance Adjunction f g => Adjunction (Yoneda f) (Yoneda g) where
  unit = liftYoneda . fmap liftYoneda . unit
  counit (Yoneda m) = counit (m lowerYoneda)

-- instance Show1 f => Show1 (Yoneda f) where
instance Show (f a) => Show (Yoneda f a) where
  showsPrec d (Yoneda f) = showParen (d > 10) $
    showString "liftYoneda " . showsPrec 11 (f id)

-- instance Read1 f => Read1 (Yoneda f) where
#ifdef __GLASGOW_HASKELL__
instance (Functor f, Read (f a)) => Read (Yoneda f a) where
  readPrec = parens $ prec 10 $ do
     Ident "liftYoneda" <- lexP
     liftYoneda <$> step readPrec
#endif

instance Eq (f a) => Eq (Yoneda f a) where
  (==) = (==) `on` lowerYoneda

instance Ord (f a) => Ord (Yoneda f a) where
  compare = compare `on` lowerYoneda

maxF :: (Functor f, Ord (f a)) => Yoneda f a -> Yoneda f a -> Yoneda f a
Yoneda f `maxF` Yoneda g = liftYoneda $ f id `max` g id
-- {-# RULES "max/maxF" max = maxF #-}
{-# INLINE maxF #-}

minF :: (Functor f, Ord (f a)) => Yoneda f a -> Yoneda f a -> Yoneda f a
Yoneda f `minF` Yoneda g = liftYoneda $ f id `max` g id
-- {-# RULES "min/minF" min = minF #-}
{-# INLINE minF #-}

maxM :: (Monad m, Ord (m a)) => Yoneda m a -> Yoneda m a -> Yoneda m a
Yoneda f `maxM` Yoneda g = lift $ f id `max` g id
-- {-# RULES "max/maxM" max = maxM #-}
{-# INLINE maxM #-}

minM :: (Monad m, Ord (m a)) => Yoneda m a -> Yoneda m a -> Yoneda m a
Yoneda f `minM` Yoneda g = lift $ f id `min` g id
-- {-# RULES "min/minM" min = minM #-}
{-# INLINE minM #-}

instance Alt f => Alt (Yoneda f) where
  Yoneda f <!> Yoneda g = Yoneda (\k -> f k <!> g k)

instance Plus f => Plus (Yoneda f) where
  zero = Yoneda $ const zero

instance Alternative f => Alternative (Yoneda f) where
  empty = Yoneda $ const empty
  Yoneda f <|> Yoneda g = Yoneda (\k -> f k <|> g k)

instance Bind m => Bind (Yoneda m) where
  Yoneda m >>- k = Yoneda (\f -> m id >>- \a -> runYoneda (k a) f)
  
instance Monad m => Monad (Yoneda m) where
  return a = Yoneda (\f -> return (f a))
  Yoneda m >>= k = Yoneda (\f -> m id >>= \a -> runYoneda (k a) f)

instance MonadFix m => MonadFix (Yoneda m) where
  mfix f = lift $ mfix (lowerYoneda . f)

instance MonadPlus m => MonadPlus (Yoneda m) where
  mzero = Yoneda (const mzero)
  Yoneda f `mplus` Yoneda g = Yoneda (\k -> f k `mplus` g k)

instance MonadTrans Yoneda where
  lift a = Yoneda (\f -> liftM f a)

instance (Functor f, MonadFree f m) => MonadFree f (Yoneda m) where
  wrap = lift . wrap . fmap lowerYoneda

instance Extend w => Extend (Yoneda w) where
  extend k (Yoneda m) = Yoneda (\f -> extend (f . k . liftYoneda) (m id))

instance Comonad w => Comonad (Yoneda w) where
  extract = extract . lowerYoneda 

instance ComonadTrans Yoneda where
  lower = lowerYoneda 
