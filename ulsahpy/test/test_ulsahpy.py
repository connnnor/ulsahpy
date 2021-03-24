import unittest

from ulsahpy import ulsahpy

class TestOrdinal(unittest.TestCase):

    ord_d = {1 :"st", 2 : "nd", 3 : "rd"}
    def test_first(self):
        self.assertEqual(ulsahpy.ordinal(1), '1st')

    def test_second(self):
        self.assertEqual(ulsahpy.ordinal(2), '2nd')

    def test_third(self):
        self.assertEqual(ulsahpy.ordinal(3), '3rd')

    def test_others(self):
        self.assertEqual(ulsahpy.ordinal(0), '0th')
        self.assertEqual(ulsahpy.ordinal(99), '99th')

if __name__ == '__main__':
    unittest.main()

