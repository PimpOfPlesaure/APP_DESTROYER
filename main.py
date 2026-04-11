#!/usr/bin/env python3
import os
import subprocess
import sys
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from rich.text import Text
from rich.spinner import Spinner
from rich.live import Live
import time
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SEARCH_SCRIPT = os.path.join(BASE_DIR, "search.sh")
WIPER_SCRIPT = os.path.join(BASE_DIR, "wiper.sh")

console = Console()


def ask(prompt_text):
    value = Prompt.ask(prompt_text).strip()
    if value.upper() == "EXIT":
        console.print()
        console.print("[yellow]--------------GOODBYE PUSSY--------------[/yellow]")
        sys.exit(0)
    return value


def banner():
    console.clear()
    title = Text()
    title.append("\n  WELCOME TO THE GREAT ALEXANDER APP CLEANER\n", style="bold white")
    console.print(Panel(title, border_style="bright_red", padding=(0, 10)))
    console.print()


def select_mode():
    console.print(Panel(
        "[bold yellow]What do you want to evaporate?[/bold yellow]\n\n"
        "  [bold cyan]\\[1][/bold cyan]  Application  → full purge, bundle ID + all traces\n"
        "  [bold cyan]\\[2][/bold cyan]  File/Folder  → target + related cache/log traces\n\n"
        "  [dim]Type EXIT anytime to quit[/dim]",
        border_style="yellow",
        padding=(1, 4)
    ))
    console.print()

    while True:
        mode = ask("[bold white]>>>[/bold white]")
        if mode in ["1", "2"]:
            return mode
        console.print("[red]Invalid choice. Please enter 1 or 2.[/red]")


def get_query(mode):
    label = "Application name" if mode == "1" else "File/Folder name"
    console.print()
    console.print(Panel(
        f"[bold yellow]Give me the name of the shit that we need to evaporate![/bold yellow]\n"
        f"[dim]{label}[/dim]",
        border_style="yellow",
        padding=(1, 4)
    ))
    console.print()

    while True:
        query = ask("[bold white]>>>[/bold white]")
        if query:
            return query
        console.print("[red]Query cannot be empty![/red]")


def run_search(mode, query):
    console.print()
    console.print(Panel(
        f"[bold green]--SCANING FOR--:[/bold green] [white]{query}[/white]\n"
        f"[bold green]--MODE--:[/bold green] [white]{'Application' if mode == '1' else 'File/Folder'}[/white]",
        border_style="green",
        padding=(1, 4)
    ))
    console.print()

    with Live(Spinner("dots", text="[cyan]Scanning, please wait...[/cyan]"), refresh_per_second=10):
        process = subprocess.Popen(
            ["bash", SEARCH_SCRIPT, mode, query],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate()

    for line in stderr.splitlines():
        if line.startswith("[LOG]"):
            console.print(f"[cyan]{line}[/cyan]")

    found_paths = [line for line in stdout.splitlines() if line.strip()]

    if not found_paths:
        console.print("[yellow]No items found.[/yellow]")
        sys.exit(0)

    return found_paths


def show_preview(found_paths):
    console.print()
    console.print(Panel(
        "[bold white]ITEMS SCHEDULED FOR PERMANENT DELETION[/bold white]",
        border_style="bright_red",
        padding=(0, 4)
    ))
    console.print()

    total_size = 0
    for path in found_paths:
        if os.path.exists(path):
            result = subprocess.run(
                ["du", "-sk", path],
                capture_output=True, text=True
            )
            try:
                size_kb = int(result.stdout.split()[0])
                total_size += size_kb
                size_mb = size_kb / 1024
                console.print(f"  [dim white][{size_mb:.1f} MB][/dim white] {path}")
            except (ValueError, IndexError):
                console.print(f"  [dim white][? MB][/dim white] {path}")

    console.print()
    console.print(f"[bold]  TOTAL SIZE: {total_size / 1024:.2f} MB[/bold]")
    console.print()


def confirm_and_wipe(found_paths):
    console.print(Panel(
        "[bold red]⚠️  WARNING: This operation is IRREVERSIBLE.\n"
        "Files will be wiped with AES-256 encryption + key destruction.\n"
        "There is NO recovery after this point.[/bold red]",
        border_style="red",
        padding=(1, 4)
    ))
    console.print()

    confirm = ask(
        "[bold white]  Type [bold red]CONFIRM[/bold red] to proceed or anything else to abort[/bold white]"
    )

    if confirm != "CONFIRM":
        console.print()
        console.print("[yellow][✗] Operation aborted. No files were deleted.[/yellow]")
        sys.exit(0)

    console.print()
    console.print("[bold green][✓] Confirmed. Initiating secure wipe...[/bold green]")
    console.print()

    path_input = "\n".join(found_paths) + "\n"

    process = subprocess.Popen(
        ["bash", WIPER_SCRIPT],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    stdout, _ = process.communicate(input=path_input)

    for line in stdout.splitlines():
        if line.startswith("[✓]"):
            console.print(f"[green]{line}[/green]")
        elif line.startswith("[!]"):
            console.print(f"[yellow]{line}[/yellow]")
        elif line.startswith("==="):
            console.print(f"[bold bright_red]{line}[/bold bright_red]")
        elif line:
            console.print(line)

    console.print()
    console.print(Panel(
        "[bold green]  EVAPORATION COMPLETE[/bold green]",
        border_style="green",
        padding=(1, 4)
    ))


def main():
    banner()
    mode = select_mode()
    query = get_query(mode)
    found_paths = run_search(mode, query)
    show_preview(found_paths)
    confirm_and_wipe(found_paths)


if __name__ == "__main__":
    main()