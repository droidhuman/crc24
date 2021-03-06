{- |
Module      : Ads_b
Description : contains functions for CRC-24 calculating and checking
Copyright   : (c) RomeoGolf, 2020
License     : MIT License
Maintainer  : triangulumsoft@gmail.com
Stability   : experimental

This module is dedicated to a parity checking for messages in secondary
surveillance radar system (aircraft transponder, mode S)

> CRC-24 description:
>   Name : CRC-24/ADS-B
>  Width : 24
>   Poly : FFF409 (hex)
>   Init : 000000
>  RefIn : false
> RefOut : false
> XorOut : address(*)
>  Check : A05E66 (**)

(*) address:

- modified address from @AA@ field for mode-S uplink or address for downlink
- modified address @0xFFFFFF@ for All-Call in mode-S (uplink),
- interrogator identifier from II field for respondes (the 24 bits, where the
  last 4 bits is the identifier and the 20 bits have zero value),
- 0 for autogenerated squitters

(**)
Check = CRC-24 for the @«123456789»@ string or @{ 0x31, 0x32, 0x33, 0x34,
0x35, 0x36, 0x37, 0x38, 0x39 }@

From the "MINIMUM OPERATIONAL PERFORMANCE SPECIFICATION FOR
SECONDARY SURVEILLANCE RADAR MODE S TRANSPONDERS" document:

> The following combinations of texts and interrogation
> addresses AA will result in AP as shown:
>
> UF=4,  all fields = 0, AA = CO 51 F6 {HEX} : AP = all ZEROs.
> UF=4,  all fields = 0, AA = 3F AB F2 {HEX} : AP = AA AA AA {HEX}.
> UF=20, all fields = 0, AA = AC C5 55 {HEX} : AP = all ZEROs.
> UF=20, all fields = 0, AA = 53 3F 51 {HEX} : AP = AA AA AA {HEX}.
>
> DF=5,  all fields = 0, AA = 20 78 CE {HEX} : AP = all ZEROs.
> DF=5,  all fields = 0, AA = 75 2D 9B {HEX} : AP = 55 55 55 {HEX}.
> DF=21, all fields = 0, AA = 0B 15 4F {HEX} : AP = all ZEROs.
> DF=2l, all fields = 0, AA = 5E 40 1A {HEX} : AP = 55 55 55 {HEX}.

To encode AP field in the MODE-S uplink:

1. Calculate CRC-24 for the message with zero values in the 3 low bytes.
2. Encode the interrogator MODE-S address. Use the @0xFFFFFF@ address for
the all-call (UF11).
3. Calculate AP field: @\<CRC-24\>@ XOR @\<modified address\>@.

Don`t need the address encoding for the АР field in the MODE-S downlink.
Use the address as is. Interrogator identifier may be as addres
(if it was in the interrogation)

The address must be encoded for the AP field in the MODE-S uplink.
The address  must be multiplied om polynom CRC-24, then most significant
24 bits is used.

For example:

> For AA = 0xC051F6 encoded address is: 0x80665F
> For AA = 0x3FABF2 encoded address is: 0x2ACCF5
> For AA = 0xACC555 encoded address is: 0xC88294
> For AA = 0x533F51 encoded address is: 0x62283E

CRC-24 for transmitted data:

> UF/DF 4:    0x20 00 00 00 00 00 00,                       CRC-24 = 0x80665F
> UF/DF 5:    0x28 00 00 00 00 00 00,                       CRC-24 = 0x2078CE
> UF/DF 20:   0xA0 00 00 00 00 00 00 00 00 00 00 00 00 00,  CRC-24 = 0xC88294
> UF/DF 21:   0xA8 00 00 00 00 00 00 00 00 00 00 00 00 00,  CRC-24 = 0x0B154F

The encoded all-call address @(0xFFFFFF)@ = @0xAAAC07@

UF11 with zero fields = @0x58000000@, CRC-24 = @0xE0EF0D@, AP = @0x4A430A@

Example DF11 squitter:

> 0x 5F 11 22 31 3F 07 8D
> 0x5F: DF11 and CA field = 3
> 0x112231 – MODE-S address
> 0x3F078D – CRC-24

And so @'crc24' [0x8d, 0x07, 0x3f, 0x31, 0x22, 0x11, 0x5f]@ = 0
-}

module Ads_b
    (
      crc24
    , crc24DataOnly
    , crc24XorOut
    , crc24DataOnlyXorOut
    , encodedAddress
    , apFieldForUpFormat
    , apFieldForDownFormat
    , Crc24CheckResult (CrcIsOk, Fail)
    , errorMessagePrepareData
    ) where

import Numeric (readHex, showHex)
import Data.Word (Word8, Word32)
import Data.Bits ((.|.), (.&.), shift, xor)

-- | The result of CRC-24 checksum checking.
data Crc24CheckResult
    = CrcIsOk       -- ^ if the whole message CRC-24 checksum
                    -- is equial to zero
    | Fail Word32   -- ^ if the whole message CRC-24 checksum is not equial
                    -- to zero, contains a checksum calculation result
    deriving (Eq)

mask24bits = 0x00FFFFFF

-- | The named const for error message if a data length for the 'crc24' or
-- 'crc24XorOut' functions is less than 3 bytes
errorMessagePrepareData = "The data is too short!"

preparedData :: [Word8]                 -- input list of bytes
                -> (Word32, [Word8])    -- initial buffer and the rest list
preparedData (x0:x1:x2:xs) = let
    initBuf = fromIntegral x0 `shift` 24
                .|. fromIntegral x1 `shift` 16
                .|. fromIntegral x2 `shift` 08
    in (initBuf, xs)
preparedData _ = error errorMessagePrepareData

crc24' :: (Word32, [Word8])     -- initial buffer and the rest list
            -> Word32           -- crc24 in 3 low bytes
crc24' (buf, []) = buf `shift` (-8)
crc24' (buf, x:xs) = let
    maskC :: Word32
    maskC = 0x80000000
    poly :: Word32
    poly = 0xFFF40900
    buf' = buf .|. fromIntegral x
    processedBuf :: Word32 -> Int -> Word32
    processedBuf b 0 = b
    processedBuf b cnt = let
        cBit = (b .&. maskC) /= 0
        b' = b `shift` 1
        b'' = if cBit then b' `xor` poly else b'
        in processedBuf b'' (pred cnt)
    in crc24' (processedBuf buf' 8, xs)

-- | The 'crc24' functions calculates CRC-24 for an input data list,
-- e. g. 7 bytes for DF11 or 14 bytes for DF21. The input data should be
-- a whole message with data bytes and 3 bytes of CRC-24. The input data
-- length should be at least 3 bytes. The result should be 'CrcIsOk' for
-- correct input messages.
crc24 :: [Word8]                -- ^ the input bytes list with CRC-24 checksum
                                -- in a 3 low bytes
         -> Crc24CheckResult    -- ^ the result of CRC-24 checking
crc24 msg = let result = (crc24' . preparedData . reverse) msg in
    case result of
        0 -> CrcIsOk
        _ -> Fail result

-- | The 'crc24XorOut' functions calculates an input data list CRC-24
-- checksum XORed with the first argument. The input data should be a whole
-- message with data bytes and 3 bytes of CRC-24. The input data length should
-- be at least 3 bytes.
-- The result should be 'CrcIsOk' for correct input messages.
crc24XorOut ::
        Word32                  -- ^ the data for XORing (XorOut)
         -> [Word8]             -- ^ the input bytes list with 3 CRC-24
                                --   low bytes
         -> Crc24CheckResult    -- ^ the result of CRC-24 checking
crc24XorOut xorData msg = let
    result = (crc24' . preparedData . reverse) msg
        `xor` (xorData .&. mask24bits) in
    case result of
        0 -> CrcIsOk
        _ -> Fail result

-- | The crc24DataOnly function calculates CRC-24 checksum for an input
-- data list, e.g. 4 bytes for DF11 or 11 bytes for DF21. 3 low bytes of
-- result is the CRC-24.
crc24DataOnly :: [Word8]    -- ^ the input data list, a head is LSB
                -> Word32   -- ^ the CRC-24 checksum in 3 low bytes
crc24DataOnly xs = (crc24' . preparedData . reverse) $ 0:0:0:xs

-- | The 'crc24DataOnlyXorOut> function calculates an input data list CRC-24
-- checksum XORed with the first argument. 3 low bytes of result is the CRC-24.
crc24DataOnlyXorOut :: Word32   -- ^ the data for XORing (XorOut)
                    -> [Word8]  -- ^ the input data list, a head is LSB
                    -> Word32   -- ^ the CRC-24 checksum in 3 low bytes
crc24DataOnlyXorOut xorData xs = (.&.) mask24bits $ crc24DataOnly xs
    `xor` xorData

-- helper function for an address encoding
encodedAddress' :: Word32       -- the MODE-S address
                   -> Word32    -- the CRC24 polynom
                   -> Word32    -- the buffer for a result
                   -> Int       -- the counter for recurrent invoking
                   -> Word32    -- the encoded address
encodedAddress' addr poly buff 0 = buff .&. mask24bits -- 24 low bits
encodedAddress' addr poly buff cnt = let
    maskC :: Word32
    maskC = 0x01000000
    addr' = addr `shift` 1
    poly' = poly `shift` (-1)
    buff' = if addr' .&. maskC /= 0 then buff `xor` poly' else buff
    in encodedAddress' addr' poly' buff' (pred cnt)

-- | The 'encodedAddress' functions encodes aircraft mode-S address for
-- uplink messages
encodedAddress :: Word32        -- ^ the MODE-S aircraft address in 3 low bytes
                  -> Word32     -- ^ the encoded address
encodedAddress addr = encodedAddress' addr poly 0 24 where
    poly :: Word32
    poly = 0x01FFF409

-- | The 'apFieldForUpFormat' function calculates an AP field for
-- uplink messages
apFieldForUpFormat :: [Word8]     -- ^ the input bytes: whole message
                                  -- (e. g. 7 or 14 bytes) with zeroes
                                  -- in 3 low bytes
                      -> Word32   -- ^ the MODE-S aircraft address in
                                  -- 3 low bytes
                      -> Word32   -- ^ AP field in 3 low bytes
apFieldForUpFormat bytes addr = let
    bytes' = (tail . tail . tail) bytes
    crc = crc24DataOnly bytes'
    addr' = encodedAddress addr
    in crc `xor` addr'

-- | The 'apFieldForDownFormat' function calculates an AP field for
-- downlink messages
apFieldForDownFormat :: [Word8]   -- ^ the input bytes: whole message
                                  -- (e. g. 7 or 14 bytes) with zeroes
                                  -- in 3 low bytes
                      -> Word32   -- ^ the MODE-S aircraft address
                                  -- in 3 low bytes
                      -> Word32   -- ^ AP field in 3 low bytes
apFieldForDownFormat bytes addr = let
    bytes' = (tail . tail . tail) bytes
    crc = crc24DataOnly bytes'
    in crc `xor` addr
