{-# LANGUAGE TemplateHaskell #-}

import Test.QuickCheck
import Test.HUnit
import Test.Tasty
import Test.Hspec
import Test.DocTest

import Ads_b

import Data.Word (Word8, Word32)
import Data.Bits ((.|.), (.&.), shift, xor)

prop_reverseReverse :: [Int] -> Bool
prop_reverseReverse xs = reverse (reverse xs) == xs

prop_Crc24 :: [Word8] -> Bool
prop_Crc24 xs = crc24 (x1:x2:x3:xs) == 0 where
    crc' = crc24DataOnly xs
    x1 = fromIntegral (crc' Data.Bits..&. 0xFF)
    x2 = fromIntegral ((crc' `shift` (-8)) Data.Bits..&. 0xFF)
    x3 = fromIntegral ((crc' `shift` (-16)) Data.Bits..&. 0xFF)

prop_Crc24XorOutUplink :: Word32 -> [Word8] -> Bool
prop_Crc24XorOutUplink xorData xs = crc24XorOut xorData' (x1:x2:x3:xs) == 0 where
    xorData' = xorData --    Data.Bits..&. 0xFFFFFF
    crc' = crc24DataOnlyXorOut xorData' xs
    x1 = fromIntegral (crc' Data.Bits..&. 0xFF)
    x2 = fromIntegral ((crc' `shift` (-8)) Data.Bits..&. 0xFF)
    x3 = fromIntegral ((crc' `shift` (-16)) Data.Bits..&. 0xFF)

{-UF/DF 4:    0x20 00 00 00 00 00 00,                         CRC-24 = 80665F-}
{-UF/DF 5:    0x28 00 00 00 00 00 00,                         CRC-24 = 2078CE-}
{-UF/DF 20:   0xA0 00 00 00 00 00 00 00 00 00 00 00 00 00,    CRC-24 = C88294-}
{-UF/DF 21:   0xA8 00 00 00 00 00 00 00 00 00 00 00 00 00,    CRC-24 = 0B154F-}

testData :: [Word8]
testData = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]
check = 0xA05E66

testMsg1, testMsg2, testMsg3, testMsg4 :: [Word8]
testMsg1 = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20]
testMsg2 = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA0]
testMsg3 = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x28]
testMsg4 = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA8]

testAddr1, testAddr2, testAddr3, testAddr4 :: Word32
testAddr1 = 0x00C051F6
testAddr2 = 0x003FABF2
testAddr3 = 0x00ACC555
testAddr4 = 0x00533F51

testAddrDf1, testAddrDf2, testAddrDf3, testAddrDf4 :: Word32
testAddrDf1 = 0x002078CE
testAddrDf2 = 0x00752D9B
testAddrDf3 = 0x000b154F
testAddrDf4 = 0x005E401A

crc1, crc2, crc3, crc4 :: Word32
crc1 = 0x80665F
crc2 = 0xC88294
crc3 = 0x2078CE
crc4 = 0x0B154F

ap1 = 0
ap2 = 0xAAAAAA
ap3 = 0x555555

encAddr1 = 0x80665F
encAddr2 = 0x2ACCF5
encAddr3 = 0xC88294
encAddr4 = 0x62283E

testEncAddr1 = TestCase (assertEqual "encode address (1):" encAddr1 (encodedAddress testAddr1))
testEncAddr2 = TestCase (assertEqual "encode address (2):" encAddr2 (encodedAddress testAddr2))
testEncAddr3 = TestCase (assertEqual "encode address (3):" encAddr3 (encodedAddress testAddr3))
testEncAddr4 = TestCase (assertEqual "encode address (4):" encAddr4 (encodedAddress testAddr4))

testCrc24 = TestCase (assertEqual "test CRC24 (main):" check (crc24DataOnly testData))

testCrc1 = TestCase (assertEqual "for crc24 (1):" (crc1) (crc24 testMsg1))
testCrc2 = TestCase (assertEqual "for crc24 (2):" (crc2) (crc24 testMsg2))
testCrc3 = TestCase (assertEqual "for crc24 (3):" (crc3) (crc24 testMsg3))
testCrc4 = TestCase (assertEqual "for crc24 (4):" (crc4) (crc24 testMsg4))

testAp1= TestCase (assertEqual "for AP (1):" (ap1) (apFieldForUpFormat testMsg1 testAddr1))
testAp2= TestCase (assertEqual "for AP (2):" (ap2) (apFieldForUpFormat testMsg1 testAddr2))
testAp3= TestCase (assertEqual "for AP (3):" (ap1) (apFieldForUpFormat testMsg2 testAddr3))
testAp4= TestCase (assertEqual "for AP (4):" (ap2) (apFieldForUpFormat testMsg2 testAddr4))

testApDf1= TestCase (assertEqual "for DF AP (1):" (ap1) (apFieldForDownFormat testMsg3 testAddrDf1))
testApDf2= TestCase (assertEqual "for DF AP (2):" (ap3) (apFieldForDownFormat testMsg3 testAddrDf2))
testApDf3= TestCase (assertEqual "for DF AP (3):" (ap1) (apFieldForDownFormat testMsg4 testAddrDf3))
testApDf4= TestCase (assertEqual "for DF AP (4):" (ap3) (apFieldForDownFormat testMsg4 testAddrDf4))

testApDf'1 = TestCase (assertEqual "for DF AP ('1):" (0) (apFieldForDownFormat [ 0x98, 0x60, 0x57, 0xE0, 0x2C, 0xC3, 0x71, 0xC3, 0x2C, 0x20, 0xD6, 0x40, 0x48, 0x8D ] 0))
testApDf'2 = TestCase (assertEqual "for DF AP ('2):" (0) (apFieldForDownFormat [ 0x00, 0x00, 0x00, 0xE0, 0x2C, 0xC3, 0x71, 0xC3, 0x2C, 0x20, 0xD6, 0x40, 0x48, 0x8D ] 0x576098))
testApDf'3 = TestCase (assertEqual "for DF AP ('2):" (0) (apFieldForDownFormat [ 166, 85, 122, 35, 32, 77, 93 ] 0))
testApDf'4 = TestCase (assertEqual "for DF AP ('2):" (0) (apFieldForDownFormat [ 0x8D, 0x07, 0x3F, 0x31, 0x22, 0x11, 0x5F ] 0))
testApDf'5 = TestCase (assertEqual "for DF AP ('2):" (0) (apFieldForDownFormat  [ 0x00, 0x00, 0x00, 0x31, 0x22, 0x11, 0x5F ] 0x3F078D))
testApDf'6 = TestCase (assertEqual "for DF AP ('2):" (0) (apFieldForDownFormat  [ 0x00, 0x00, 0x00, 0x00, 0x00, 0xa4, 0x30, 0x00, 0xb0, 0x8d, 0x37, 0x0b, 0x00, 0xA0 ] 0x98F94F))

tests = TestList [TestLabel "crc24 main" testCrc24
        , TestLabel "calc uplink AP 1" testAp1
        , TestLabel "calc uplink AP 2" testAp2
        , TestLabel "calc uplink AP 3" testAp3
        , TestLabel "calc uplink AP 4" testAp4
        , TestLabel "calc downlink AP 1" testApDf1
        , TestLabel "calc downlink AP 2" testApDf2
        , TestLabel "calc downlink AP 3" testApDf3
        , TestLabel "calc downlink AP 4" testApDf4
        , TestLabel "calc downlink AP '1" testApDf'1
        , TestLabel "calc downlink AP '2" testApDf'2
        , TestLabel "calc downlink AP '2" testApDf'3
        , TestLabel "calc downlink AP '2" testApDf'4
        , TestLabel "calc downlink AP '2" testApDf'5
        , TestLabel "calc downlink AP '2" testApDf'6
        , TestLabel "crc24-1" testCrc1, TestLabel "crc24-2" testCrc2
        , TestLabel "crc24-3" testCrc3, TestLabel "crc24-4" testCrc4
        , TestLabel "encode addr test 2" testEncAddr2
        , TestLabel "encode addr test 3" testEncAddr3
        , TestLabel "encode addr test 4" testEncAddr4]


return []
{-main :: IO ()-}
{-main = putStrLn "Test suite not yet implemented"-}
main = do
    $(quickCheckAll)
    runTestTT tests
{-main = quickCheck prop_Crc24-}
