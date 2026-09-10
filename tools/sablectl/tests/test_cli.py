from sablectl.cli import build_parser


def test_parser_smoke_requires_target_files():
    parser = build_parser()
    args = parser.parse_args(["smoke", "--target-files", "x.zip", "--expected-slot", "b"])
    assert args.command == "smoke"
    assert args.target_files == "x.zip"
    assert args.expected_slot == "b"


def test_parser_acceptance_d4_requires_bound_inputs():
    parser = build_parser()
    args = parser.parse_args([
        "acceptance", "d4",
        "--target-files", "x.zip",
        "--baseline", "baseline.json",
        "--expected-slot", "b",
        "--require-complete",
    ])
    assert args.command == "acceptance"
    assert args.acceptance_command == "d4"
    assert args.target_files == "x.zip"
    assert args.baseline == "baseline.json"
    assert args.expected_slot == "b"
    assert args.require_complete is True
