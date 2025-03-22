import os
import re
import sys
import statistics
import time

from pywinauto import Application  # type: ignore


class ResourceMonitor:
    def __init__(self, log_file, duration=10):
        self.log_file = log_file
        self.duration = int(duration)  # Monitor duration in seconds
        self.cpu_usage = []
        self.npu_usage = []
        self.memory_usage = []
        self.app = None
        self.taskmgr = None

    def start_task_manager(self):
        """Launches Task Manager if not already open,
           else attaches to the existing instance and ensures visibility."""
        try:
            # Try attaching to an existing Task Manager instance
            self.app = Application(backend="uia").connect(
                title_re="Task Manager", timeout=2)
            print("Attached to existing Task Manager instance.")
        except Exception:
            # If not found, start a new instance
            try:
                self.app = Application(backend="uia").start("taskmgr.exe")
                time.sleep(3)  # Ensure Task Manager UI is loaded
                print("Task Manager launched successfully!")
            except Exception as e:
                print(f"Failed to start Task Manager: {e}")
                exit()

        # Get Task Manager window
        try:
            self.taskmgr = self.app.window(title_re="Task Manager")
            # Maximize Task Manager window
            self.taskmgr.maximize()
            # Bring Task Manager to the foreground
            self.taskmgr.set_focus()
            time.sleep(1)  # Allow UI to update
            print("Task Manager maximized.")

            # Handle Compact Mode (click 'More details' if present)
            more_details_btn = self.taskmgr.child_window(title="More details",
                                                         control_type="Button")
            if more_details_btn.exists():
                more_details_btn.click()
                time.sleep(1)
                print("Switched Task Manager to full mode.")

            print("Task Manager is ready in full mode.")

        except Exception as e:
            print(f"Failed to interact with Task Manager: {e}")
            exit()

    def minimize_task_manager(self):
        self.taskmgr.minimize()

    def maximize_task_manager(self):
        self.taskmgr.maximize()

    def restore_task_manager(self):
        if self.taskmgr.is_minimized():
            self.taskmgr.restore()
            self.taskmgr.set_focus()
            self.taskmgr.maximize()

    def switch_to_performance_tab(self):
        """Navigates to the 'Performance' tab in Task Manager."""
        try:
            performance_tab = self.taskmgr.child_window(
                title="Performance",
                control_type="ListItem"
                )
            performance_tab.click_input()
            time.sleep(1)  # Allow UI update
            print("Switched to Performance Tab!")
        except Exception as e:
            print(f"Failed to switch to Performance Tab! Error: {e}")
            exit()

    def extract_percentage(self, text):
        """Extracts percentage value from a given text string."""
        match = re.search(r"(\d+)%", text)
        return int(match.group(1)) if match else None

    def get_utilization(self):
        """Fetches CPU, Memory, and NPU utilization from Task Manager."""
        try:
            # Get CPU utilization
            cpu_item = self.taskmgr.child_window(auto_id="sidebar_cpu_util",
                                                 control_type="Edit")
            cpu_util = self.extract_percentage(cpu_item.window_text())

            # Get Memory utilization
            memory_item = self.taskmgr.child_window(auto_id="sidebar_mem_util",
                                                    control_type="Edit")
            memory_util = self.extract_percentage(memory_item.window_text())

            # Find and get NPU utilization dynamically
            npu_util = None
            for btn in self.taskmgr.descendants(control_type="Button"):
                if "NPU" in btn.window_text():
                    btn.click_input()
                    npu_util = self.extract_percentage(btn.window_text())
                    break

            return cpu_util, memory_util, npu_util

        except Exception as e:
            print(f"Failed to capture utilization data: {e}")
            return None, None, None

    def log_utilization(self):
        """Log Resource (CPU/NPU/Memory) utilization to a text file
        with timestamp and summarize with Peak, Median and Average Values."""

        file_exists = os.path.isfile(self.log_file)

        # Choose mode: 'w' for new file, 'a' for append
        mode = "a" if file_exists else "w"

        with open(self.log_file, mode) as log:
            if not file_exists:
                # If creating a new file, add headers
                log.write("Before Test Execution\n")
                log.write(
                    "Timestamp, "
                    "CPU Utilization (%), "
                    "Memory Utilization (%), "
                    "NPU Utilization (%)\n"
                )
            else:
                log.write("\nAfter Test Execution\n")

            interval = 1  # interval between measurements (in seconds)

            for i in range(self.duration):
                iteration_start = time.time()

                # Get utilization data
                cpu, memory, npu = self.get_utilization()

                # Append utilization values if they are valid
                if cpu is not None:
                    self.cpu_usage.append(cpu)
                if memory is not None:
                    self.memory_usage.append(memory)
                if npu is not None:
                    self.npu_usage.append(npu)

                # Log current utilization with timestamp
                timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                log.write(f"{timestamp}, {cpu}, {memory}, {npu}\n")

                # Calculate time taken for the iteration
                elapsed = time.time() - iteration_start
                sleep_time = max(0, interval - elapsed)

                # Sleep only the remaining time to maintain consistent interval
                time.sleep(sleep_time)

            # After collecting data, calculate and write statistics
            self.calculate_statistics(log)

    def calculate_statistics(self, log):
        """Calculates median, average, and peak utilization and logs it"""
        def stats(data):
            return {
                "Median": statistics.median(data) if data else "N/A",
                "Average": round(statistics.mean(data), 2) if data else "N/A",
                "Peak": max(data) if data else "N/A",
            }

        cpu_stats = stats(self.cpu_usage)
        memory_stats = stats(self.memory_usage)
        npu_stats = stats(self.npu_usage)

        log.write("\n--- Utilization Statistics ---\n")
        log.write(
            f"CPU - Median: {cpu_stats['Median']}%, "
            f"Average: {cpu_stats['Average']}%, "
            f"Peak: {cpu_stats['Peak']}%\n"
        )
        log.write(
            f"Memory - Median: {memory_stats['Median']}%, "
            f"Average: {memory_stats['Average']}%, "
            f"Peak: {memory_stats['Peak']}%\n"
        )
        log.write(
            f"NPU - Median: {npu_stats['Median']}%, "
            f"Average: {npu_stats['Average']}%, "
            f"Peak: {npu_stats['Peak']}%\n"
        )

        print("\n--- Resource Utilization Stats ---")
        print(
            f"CPU - Median: {cpu_stats['Median']}%, "
            f"Average: {cpu_stats['Average']}%, "
            f"Peak: {cpu_stats['Peak']}%"
        )
        print(
            f"Memory - Median: {memory_stats['Median']}%, "
            f"Average: {memory_stats['Average']}%, "
            f"Peak: {memory_stats['Peak']}%"
        )
        print(
            f"NPU - Median: {npu_stats['Median']}%, "
            f"Average: {npu_stats['Average']}%, "
            f"Peak: {npu_stats['Peak']}%"
        )

    def close_task_manager(self):
        """Closes Task Manager."""
        self.taskmgr.close()

    def start_resource_monitoring(self):
        self.start_task_manager()
        self.switch_to_performance_tab()
        self.log_utilization()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            "Usage: python npu_cpu_utilization.py <method_name> [method_args]")
        sys.exit(1)

    method_name = sys.argv[1]
    log_path = sys.argv[2]
    duration = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    resource_monitor = ResourceMonitor(log_path, duration)
    # Dynamically call the method by name, and pass arguments
    if hasattr(resource_monitor, method_name):
        func = getattr(resource_monitor, method_name)
        func()
    else:
        print(f"Method not defined: {method_name}")
