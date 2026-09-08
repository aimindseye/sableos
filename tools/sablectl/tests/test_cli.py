from sablectl.cli import build_parser


def test_parser_smoke_requires_target_files():
    parser = build_parser()
    args = parser.parse_args(["smoke", "--target-files", "x.zip", "--expected-slot", "b"])
    assert args.command == "smoke"
    assert args.target_files == "x.zip"
    assert args.expected_slot == "b"
