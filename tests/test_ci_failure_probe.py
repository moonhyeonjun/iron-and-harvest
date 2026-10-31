"""IH-004 negative control: this branch must never be merged."""
import unittest

class IntentionalFailure(unittest.TestCase):
    def test_ci_must_block_this_pull_request(self):
        self.fail("IH-004 intentional failure: validate CI and merge protection")
