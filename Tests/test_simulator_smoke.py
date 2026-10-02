"""No Xcode required: validate the simulator launch PID detector."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "field_simulator_smoke", Path(__file__).with_name("simulator-smoke.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class SimulatorSmokeParserTests(unittest.TestCase):
    def test_valid_simctl_pid(self):
        self.assertEqual(module.pid_from_output("com.fieldos.native: 12345\n"), 12345)

    def test_independent_probe_pid(self):
        self.assertEqual(module.pid_from_output(
            "com.fieldos.runnerprobe: 4567\n", bundle="com.fieldos.runnerprobe"), 4567)

    def test_reject_unrelated_app(self):
        self.assertIsNone(module.pid_from_output("com.apple.mobilesafari: 12345\n"))

    def test_reject_error_or_invalid_pid(self):
        self.assertIsNone(module.pid_from_output("An error was encountered processing the command"))
        self.assertIsNone(module.pid_from_output("com.fieldos.native: none"))

if __name__ == "__main__":
    unittest.main()
