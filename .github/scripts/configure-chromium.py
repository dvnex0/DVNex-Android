import ast
from pathlib import Path

path = Path("chromium/.gclient")
source = path.read_text()
tree = ast.parse(source)

solutions = next(
    node.value
    for node in tree.body
    if isinstance(node, ast.Assign)
    and any(isinstance(target, ast.Name) and target.id == "solutions" for target in node.targets)
)

solution = next(
    item
    for item in solutions.elts
    if isinstance(item, ast.Dict)
    and any(
        isinstance(key, ast.Constant)
        and key.value == "name"
        and isinstance(value, ast.Constant)
        and value.value == "src"
        for key, value in zip(item.keys, item.values)
    )
)

custom_vars = next(
    (
        value
        for key, value in zip(solution.keys, solution.values)
        if isinstance(key, ast.Constant) and key.value == "custom_vars"
    ),
    None,
)

lines = source.splitlines(keepends=True)

def absolute_offset(line: int, column: int) -> int:
    return sum(len(line_text) for line_text in lines[: line - 1]) + column

if custom_vars is None:
    position = absolute_offset(solution.end_lineno, solution.end_col_offset - 1)
    before = source[:position].rstrip()
    separator = "" if before.endswith(",") else ","
    source = (
        source[:position]
        + separator
        + '\n        "custom_vars": {"checkout_pgo_profiles": True},'
        + source[position:]
    )
else:
    if not isinstance(custom_vars, ast.Dict):
        raise SystemExit("Unexpected custom_vars format in .gclient")

    has_pgo = any(
        isinstance(key, ast.Constant) and key.value == "checkout_pgo_profiles"
        for key in custom_vars.keys
    )
    if not has_pgo:
        position = absolute_offset(custom_vars.end_lineno, custom_vars.end_col_offset - 1)
        before = source[:position].rstrip()
        separator = "" if before.endswith(",") or before.endswith("{") else ","
        source = (
            source[:position]
            + separator
            + '"checkout_pgo_profiles": True'
            + source[position:]
        )

if 'target_os = ["android"]' not in source and "target_os = ['android']" not in source:
    source += '\ntarget_os = ["android"]\n'

ast.parse(source)
path.write_text(source)
print(source)
