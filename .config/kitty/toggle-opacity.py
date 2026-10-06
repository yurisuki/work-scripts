from kittens.tui.handler import result_handler
from kitty.fast_data_types import background_opacity_of


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    current = background_opacity_of(window.os_window_id)
    boss.set_background_opacity('default' if current is not None and current >= 0.99 else '1')
