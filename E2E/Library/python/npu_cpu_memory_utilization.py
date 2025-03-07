import os
import re
import statistics
import time
from pywinauto import Application  # type: ignore


class ResourceMonitor:
    def __init__(self, log_folder, duration=10):
        self.log_file = os.path.join(log_folder,
                                     "resource_utilization.txt")
        self.duration = duration  # Monitor duration in seconds
        self.cpu_usage = []
        self.npu_usage = []
        self.memory_usage = []

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
        # Check if file already exists
        file_exists = os.path.isfile(self.log_file)

        with open(self.log_file, "a") as log:
            if not file_exists:
                # If log file is newly created, add headers
                log.write("Before Test Execution\n")
                log.write(
                    "Timestamp, "
                    "CPU Utilization (%), "
                    "Memory Utilization (%), "
                    "NPU Utilization (%)\n"
                )
            else:
                log.write("\nAfter Test Execution\n")

            for _ in range(self.duration):
                cpu, memory, npu = self.get_utilization()

                if cpu is not None:
                    self.cpu_usage.append(cpu)
                if memory is not None:
                    self.memory_usage.append(memory)
                if npu is not None:
                    self.npu_usage.append(npu)

                timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                log.write(f"{timestamp}, {cpu}, {memory}, {npu}\n")
                time.sleep(1)  # Collect data every second

            # Calculate statistics
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
