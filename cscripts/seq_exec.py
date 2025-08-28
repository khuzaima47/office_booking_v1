import shlex
import subprocess
import sys
import threading


def stream_output(process, script_name, is_stderr=False):
    # desc = '.OUT' if is_stderr else '.ERR'
    prefix = f'[{script_name}]: '
    for line in iter(process.readline, b''):
        print(prefix + line.decode().strip())


def run_cmds(commands: list[str]):
    print(f'Got {len(commands)} commands:')
    for idx, cmd in enumerate(commands):
        print(f' [{idx}]: {cmd}')
    print('-----------------------------')
    for idx, cmd in enumerate(commands):
        p = subprocess.Popen(shlex.split(cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout_thread = threading.Thread(target=stream_output, args=(p.stdout, idx))
        stderr_thread = threading.Thread(target=stream_output, args=(p.stderr, idx, True))
        stdout_thread.start()
        stderr_thread.start()
        p.wait()
        print('-----------------------------')



def main():
    run_cmds(sys.argv[1:])


if __name__ == '__main__':
    main()
