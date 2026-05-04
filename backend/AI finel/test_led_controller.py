# test_led_controller.py

import argparse
import os
import sys
import time

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(CURRENT_DIR)

from led_controller import apply_scene, turn_on, turn_off, set_rgb


DEFAULT_IP = "192.168.100.34"


def parse_args():
    parser = argparse.ArgumentParser(description="Test ClipView LED controller")

    parser.add_argument(
        "--ip",
        type=str,
        default=DEFAULT_IP,
        help="LED controller IP address",
    )

    parser.add_argument(
        "--scene",
        type=str,
        default=None,
        choices=[
            "normal",
            "focus_support",
            "recovery",
            "night_protection",
            "soft_alert",
        ],
        help="Apply one ClipView LED scene",
    )

    parser.add_argument(
        "--on",
        action="store_true",
        help="Turn LED on",
    )

    parser.add_argument(
        "--off",
        action="store_true",
        help="Turn LED off",
    )

    parser.add_argument(
        "--demo",
        action="store_true",
        help="Run all scenes one by one",
    )

    parser.add_argument(
        "--rgb",
        type=str,
        default=None,
        help='Set raw RGB, example: --rgb "255,70,0"',
    )

    parser.add_argument(
        "--brightness",
        type=int,
        default=60,
        help="Brightness percentage used with --rgb",
    )

    return parser.parse_args()


def run_demo(ip: str):
    scenes = [
        "normal",
        "focus_support",
        "recovery",
        "night_protection",
        "soft_alert",
    ]

    print("\n[TEST] Running ClipView LED scene demo...\n")

    for scene in scenes:
        print(f"\n[TEST] Scene: {scene}")
        apply_scene(ip, scene)
        time.sleep(3)

    print("\n[TEST] Demo finished.")


if __name__ == "__main__":
    args = parse_args()

    if args.on:
        turn_on(args.ip)

    elif args.off:
        turn_off(args.ip)

    elif args.rgb:
        try:
            parts = args.rgb.split(",")
            rgb = tuple(int(x.strip()) for x in parts)

            if len(rgb) != 3:
                raise ValueError

            set_rgb(args.ip, rgb, args.brightness)

        except Exception:
            print('Invalid RGB format. Use: --rgb "255,70,0"')

    elif args.scene:
        apply_scene(args.ip, args.scene)

    elif args.demo:
        run_demo(args.ip)

    else:
        print("Use one of these commands:")
        print(f'python "AI finel/test_led_controller.py" --ip {args.ip} --on')
        print(f'python "AI finel/test_led_controller.py" --ip {args.ip} --off')
        print(f'python "AI finel/test_led_controller.py" --ip {args.ip} --scene recovery')
        print(f'python "AI finel/test_led_controller.py" --ip {args.ip} --demo')
        print(f'python "AI finel/test_led_controller.py" --ip {args.ip} --rgb "255,70,0" --brightness 45')