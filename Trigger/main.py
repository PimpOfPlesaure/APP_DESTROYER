#!/usr/bin/env python3
import os
import subprocess
import sys
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from rich.text import Text

script_dir = os.path.dirname(os.path.abspath(__file__))
bash_script = os.path.join(script_dir, "main.sh")

print(script_dir)
print(bash_script)

console = Console()


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
        "  [bold cyan]\\[2][/bold cyan]  File/Folder  → target + related cache/log traces",
        border_style="yellow",
        padding=(1, 4)
    ))
    console.print()

    while True:
        mode = Prompt.ask("[bold white]>>>[/bold white]").strip()
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
        query = Prompt.ask("[bold white]>>>[/bold white]").strip()
        if query:
            return query
        console.print("[red]Query cannot be empty![/red]")

def run_discovery(mode, query):
    console.print()
    console.print(Panel(
        f"[bold green]Scanning for:[/bold green] [white]{query}[/white]\n"
        f"[bold green]Mode:[/bold green] [white]{'Application' if mode == '1' else 'File/Folder'}[/white]",
        border_style="green",
        padding=(1, 4)
    ))
    console.print()

    # Bash'i discovery modunda çalıştır (CONFIRM vermiyoruz, sadece tarama)
    process = subprocess.Popen(
        ["bash", bash_script, mode, query, "DRYRUN"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    output_lines = []

    for line in process.stdout:
        line = line.rstrip()
        output_lines.append(line)

        if line.startswith("[✓]"):
            console.print(f"[green]{line}[/green]")
        elif line.startswith("[*]"):
            console.print(f"[cyan]{line}[/cyan]")
        elif line.startswith("[!]"):
            console.print(f"[yellow]{line}[/yellow]")
        elif line.startswith("[✗]"):
            console.print(f"[red]{line}[/red]")
        elif line.startswith("  "):
            console.print(f"[dim white]{line}[/dim white]")
        elif line.startswith("==="):
            console.print(f"[bold bright_red]{line}[/bold bright_red]")
        elif line:
            console.print(line)

    process.wait()
    return output_lines

def confirm_wipe(mode, query, output_lines):
    print('confirm wife girdi !')
    console.print()
    console.print(Panel(
        "[bold red]⚠️  WARNING: This operation is IRREVERSIBLE.\n"
        "Files will be wiped with AES-256 encryption + key destruction.\n"
        "There is NO recovery after this point.[/bold red]",
        border_style="red",
        padding=(1, 4)
    ))
    console.print()

    confirm = Prompt.ask(
        "[bold white]  Type [bold red]CONFIRM[/bold red] to proceed or anything else to abort[/bold white]"
    ).strip()

    if confirm != "CONFIRM":
        console.print()
        console.print("[yellow][✗] Operation aborted. No files were deleted.[/yellow]")
        sys.exit(0)

    console.print()
    console.print("[bold green][✓] Confirmed. Initiating secure wipe...[/bold green]")
    console.print()

    # Şimdi gerçek silme — CONFIRM ile çalıştır
    process = subprocess.Popen(
        ["bash", bash_script, mode, query, "CONFIRM"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    for line in process.stdout:
        line = line.rstrip()
        if line.startswith("[✓]"):
            console.print(f"[green]{line}[/green]")
        elif line.startswith("[*]"):
            console.print(f"[cyan]{line}[/cyan]")
        elif line.startswith("[!]"):
            console.print(f"[yellow]{line}[/yellow]")
        elif line.startswith("==="):
            console.print(f"[bold bright_red]{line}[/bold bright_red]")
        elif line:
            console.print(line)

    process.wait()
    console.print()
    console.print(Panel(
        "[bold green]  EVAPORATION COMPLETE[/bold green]",
        border_style="green",
        padding=(1, 4)
    ))

def main():
    banner()
    mode = select_mode()
    print('mode ' + mode)
    query = get_query(mode)
    print('query ' + query)
    output_lines = run_discovery(mode, query)
    print(len(output_lines))
    for line in output_lines:
        print(line)
    confirm_wipe(mode, query, output_lines)


if __name__ == "__main__":
    main()