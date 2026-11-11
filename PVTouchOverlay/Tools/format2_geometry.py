"""Shared conversion of legacy control geometry."""

touch_tokens = dict(dsScreen="touchScreen", wiiPointer="pointer")


def box(frame, unit):
    return [v / unit for pair in frame for v in pair]


def make_nodes(layout, unit):
    for i, frame in enumerate(layout["screens"]):
        yield dict(
            type="screen",
            id=f"screen{i}",
            role="main" if i == 0 else "bottom",
            layout=dict(frame=box(frame, unit)),
        )
    for group in layout["groups"]:
        for control in group["controls"]:
            kind, value = next(iter(control["kind"].items()))
            node = dict(
                type="control",
                id=group["id"] + "." + control["id"],
                layout=dict(frame=box(control["frame"], unit)),
            )
            if kind == "dpad":
                node.update(
                    kind="dpad", input={k: v["token"] for k, v in value.items()}
                )
            elif kind == "touchSurface":
                node.update(kind="touchSurface", input=touch_tokens[value["_0"]])
            elif kind == "stick":
                node.update(kind="thumbstick", input=value["_0"] + "Thumbstick")
                if value.get("click"):
                    node["click"] = value["click"]["token"]
            elif kind == "action":
                node.update(kind="action", input=value["_0"])
            elif kind in ("button", "analogTrigger"):
                node.update(
                    kind="trigger" if kind == "analogTrigger" else "button",
                    input=value["_0"]["token"],
                )
            else:
                raise ValueError(f"Unmapped legacy control kind: {kind}")
            if kind != "touchSurface":
                node["hit"] = dict(
                    extend=dict.fromkeys(("top", "left", "bottom", "right"), 20)
                )
            yield node
