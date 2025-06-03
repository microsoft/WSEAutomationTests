import sys
import json
import os
import re
import statistics
import time
import pandas as pd

from pywinauto import Application  # type: ignore


class ResourceMonitor:
    def __init__(self, log_file, scenario, execution_state, duration=10):
        self.log_file = log_file
        self.scenario = scenario
        self.execution_state = execution_state
        self.duration = int(duration)  # Monitor duration in seconds
        self.cpu_usage = []
        self.npu_usage = []
        self.memory_usage = []
        self.memory_usage_gb = []
        self.memory_total_gb = []
        self.app = None
        self.taskmgr = None
        self.before_stats = {}

    def start_task_manager(self):
        """Launch or attach to Task Manager and ensure it is maximized"""
        try:
            self.app = Application(backend="uia").connect(
                title_re="Task Manager", timeout=2
            )
        except Exception:
            try:
                self.app = Application(backend="uia").start("taskmgr.exe")
                time.sleep(3)  # Wait for UI to load
            except Exception as e:
                print(f"Failed to start Task Manager: {e}")
                exit()

        try:
            self.taskmgr = self.app.window(title_re="Task Manager")
            self.taskmgr.maximize()
            self.taskmgr.set_focus()
            time.sleep(1)

            more_details_btn = self.taskmgr.child_window(
                title="More details", control_type="Button"
            )
            if more_details_btn.exists():
                more_details_btn.click()
                time.sleep(1)

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
        """Switch to the Performance tab in Task Manager."""
        try:
            performance_tab = self.taskmgr.child_window(
                title="Performance", control_type="ListItem"
            )
            performance_tab.click_input()
            time.sleep(1)
        except Exception as e:
            print(f"Failed to switch to Performance Tab! Error: {e}")
            exit()

    @staticmethod
    def extract_percentage(text):
        """Extract integer percentage from a string like '45%'."""
        match = re.search(r"(\d+)%", text)
        return int(match.group(1)) if match else None

    @staticmethod
    def extract_memory_usage(text):
        """Extract memory usage values in GB from string like '2.3/8.0'."""
        match = re.search(r"(\d+(\.\d+)?)/(\d+(\.\d+)?)", text)
        if match:
            return float(match.group(1)), float(match.group(3))
        return None, None

    def get_utilization(self):
        """Get CPU and NPU utilization in percentages and
        Memory usage in percentage and in GB."""
        try:
            cpu_item = self.taskmgr.child_window(
                auto_id="sidebar_cpu_util", control_type="Edit"
            )
            cpu_util = self.extract_percentage(cpu_item.window_text())

            memory_item = self.taskmgr.child_window(
                auto_id="sidebar_mem_util", control_type="Edit"
            )
            memory_util = self.extract_percentage(memory_item.window_text())
            memory_util_gb, memory_total_gb = self.extract_memory_usage(
                memory_item.window_text()
            )

            npu_util = None
            for btn in self.taskmgr.descendants(control_type="Button"):
                if "NPU" in btn.window_text():
                    btn.click_input()
                    npu_util = self.extract_percentage(btn.window_text())
                    break

            return (
                cpu_util,
                memory_util,
                npu_util,
                memory_util_gb,
                memory_total_gb
            )

        except Exception as e:
            print(f"Failed to capture utilization data: {e}")
            return None, None, None, None, None

    def log_utilization(self):
        """Log utilization data to file and export statistics to Excel."""

        # Get the directory of the log file
        log_dir = os.path.dirname(self.log_file)
        before_stats_path = os.path.join(log_dir, "before_stats.json")

        def save_before_stats(cpu_stats,
                            memory_stats,
                            npu_stats,
                            mem_usage_gb_stats):
            before_stats = {
                "CPU": cpu_stats,
                "Memory": memory_stats,
                "NPU": npu_stats,
                "Memory Usage (GB)": mem_usage_gb_stats,
            }
            with open(before_stats_path, "w") as f:
                json.dump(before_stats, f)

        def load_before_stats():
            try:
                with open(before_stats_path, "r") as f:
                    return json.load(f)
            except FileNotFoundError:
                return None

        file_exists = os.path.isfile(self.log_file)
        xlsx_log_file = self.log_file.replace(".txt", ".xlsx")

        mode = "a" if file_exists else "w"
        log_entries = []

        with open(self.log_file, mode) as log:
            if self.execution_state == "Before":
                log.write("\n" + "=" * 48 + "\n")
                log.write(f"Test Scenario : {self.scenario}\n")
                log.write("=" * 48 + "\n")
                log.write(f"\n{self.execution_state} Test Execution\n")
                log.write(
                    "Timestamp, CPU Utilization (%), Memory Utilization (%), "
                    "NPU Utilization (%), Memory Usage (GB)\n"
                )
            else:
                log.write(f"\n{self.execution_state} Test Execution\n")

            interval = 1  # seconds

            for _ in range(self.duration):
                start_time = time.time()

                (
                    cpu,
                    memory,
                    npu,
                    memory_util_gb,
                    memory_total_gb,
                ) = self.get_utilization()

                if cpu is not None:
                    self.cpu_usage.append(cpu)
                if memory is not None:
                    self.memory_usage.append(memory)
                if memory_util_gb is not None:
                    self.memory_usage_gb.append(memory_util_gb)
                if npu is not None:
                    self.npu_usage.append(npu)

                timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                log.write(
                    f"{timestamp},{cpu}, {memory}, {npu}, {memory_util_gb}\n"
                    )

                log_entries.append(
                    {
                        "Timestamp": timestamp,
                        "CPU Utilization (%)": cpu,
                        "Memory Utilization (%)": memory,
                        "NPU Utilization (%)": npu,
                        "Memory Usage (GB)": memory_util_gb,
                    }
                )

                elapsed = time.time() - start_time
                time.sleep(max(0, interval - elapsed))

            # Calculate stats
            cpu_stats = self._calc_stats(self.cpu_usage)
            memory_stats = self._calc_stats(self.memory_usage)
            npu_stats = self._calc_stats(self.npu_usage)
            mem_usage_gb_stats = self._calc_stats(self.memory_usage_gb)

            self.calculate_statistics(log)

            if self.execution_state == "Before":
                save_before_stats(cpu_stats,
                                  memory_stats,
                                  npu_stats,
                                  mem_usage_gb_stats)

            elif self.execution_state == "After":
                before_stats = load_before_stats()
                log.write(
                    "\n--- Statistics Difference (After vs Before) ---\n"
                    )
                print("\n--- Statistics Difference (After vs Before) ---\n")

                if before_stats:
                    for resource, stats in zip(
                        ["CPU",
                         "Memory",
                         "NPU",
                         "Memory Usage (GB)"],
                        [cpu_stats,
                         memory_stats,
                         npu_stats,
                         mem_usage_gb_stats],
                    ):
                        diffs = []
                        for key in ["Median", "Average", "Peak"]:
                            before_val = before_stats.get(
                                resource, {}).get(key)
                            after_val = stats.get(key)
                            if (
                                isinstance(before_val, (int, float)) and
                                isinstance(after_val, (int, float))
                            ):

                                diff = round(after_val - before_val, 2)
                                diffs.append(f"{key}: {diff}%")
                            else:
                                diffs.append(f"{key}: N/A")
                        log.write(f"{resource} - {', '.join(diffs)}\n")
                        print(f"{resource} - {', '.join(diffs)}\n")
                else:
                    log.write(
                        "[Warning] No 'Before' stats found. "
                        "Cannot calculate differences.\n"
                    )
            log.write(
                f"\nTotal Memory in the System (GB) : {memory_total_gb}\n"
                )

        self.export_to_excel(log_entries, xlsx_log_file)

    def _calc_stats(self, data):
        """Helper to calculate median, average, and peak for a list."""
        if not data:
            return {"Median": "N/A", "Average": "N/A", "Peak": "N/A"}
        return {
            "Median": statistics.median(data),
            "Average": round(statistics.mean(data), 2),
            "Peak": max(data),
        }

    def export_to_excel(self, data, excel_file):
        """Export utilization log entries and statistics to Excel."""
        df = pd.DataFrame(data)
        stats_data = {
            "Metric": ["CPU", "Memory", "NPU"],
            "Median (%)": [
                statistics.median(self.cpu_usage)
                if self.cpu_usage else "N/A",
                statistics.median(self.memory_usage)
                if self.memory_usage else "N/A",
                statistics.median(self.npu_usage)
                if self.npu_usage else "N/A",
            ],
            "Average (%)": [
                round(statistics.mean(self.cpu_usage), 2)
                if self.cpu_usage else "N/A",
                round(statistics.mean(self.memory_usage), 2)
                if self.memory_usage else "N/A",
                round(statistics.mean(self.npu_usage), 2)
                if self.npu_usage else "N/A",
            ],
            "Peak (%)": [
                max(self.cpu_usage)
                if self.cpu_usage else "N/A",
                max(self.memory_usage)
                if self.memory_usage else "N/A",
                max(self.npu_usage)
                if self.npu_usage else "N/A",
            ],
        }
        df_stats = pd.DataFrame(stats_data)

        with pd.ExcelWriter(excel_file) as writer:
            df.to_excel(writer, index=False, sheet_name="Utilization Log")
            df_stats.to_excel(writer, index=False, sheet_name="Statistics")

    def calculate_statistics(self, log):
        def stats(data):
            return {
                "Median": statistics.median(data) if data else "N/A",
                "Average": round(statistics.mean(data), 2) if data else "N/A",
                "Peak": max(data) if data else "N/A",
            }

        usage_data = {
            "CPU": self.cpu_usage,
            "Memory": self.memory_usage,
            "NPU": self.npu_usage,
            "Memory Usage (GB)": self.memory_usage_gb,
            # "Memory Total (GB)": self.memory_total_gb
        }

        stats_results = {
            key.replace(" ", "_")
            .replace("(", "")
            .replace(")", "")
            .replace("/", "_"): stats(data)
            for key, data in usage_data.items()
        }

        header = (
            f"\n--- {self.execution_state} Resource Utilization "
            "Statistics ---\n"
        )

        log.write(header)
        print(header)

        for label, data in usage_data.items():
            stat = stats(data)

            if "%" in label or "Memory" in label:
                log_line = (
                    f"{label} - Median: {stat['Median']}%, "
                    f"Average: {stat['Average']}%, Peak: {stat['Peak']}%\n"
                )
                print_line = (
                    f"{label} - Median: {stat['Median']}%, "
                    f"Average: {stat['Average']}%, Peak: {stat['Peak']}%"
                )
            else:
                log_line = (
                    f"{label} - Median: {stat['Median']}, "
                    f"Average: {stat['Average']}, Peak: {stat['Peak']}\n"
                )
                print_line = (
                    f"{label} - Median: {stat['Median']}, "
                    f"Average: {stat['Average']}, Peak: {stat['Peak']}"
                )

            log.write(log_line)
            print(print_line)

        return stats_results

    def close_task_manager(self):
        """Closes Task Manager."""
        self.taskmgr.close()

    def start_resource_monitoring(self):
        self.start_task_manager()
        self.switch_to_performance_tab()
        self.log_utilization()


if __name__ == "__main__":
    # Check if the script is run with the correct number of arguments
    if len(sys.argv) < 6:
        print(
            "Usage: python npu_cpu_utilization.py <method_name> <log_path> "
            "<scenario> <duration> <execution_state>"
            )
        sys.exit(1)

    method_name = sys.argv[1]
    log_path = sys.argv[2]
    scenario = sys.argv[3]
    duration = int(sys.argv[4])
    execution_state = sys.argv[5]

    resource_monitor = ResourceMonitor(log_path,
                                       scenario,
                                       execution_state,
                                       duration)

    if hasattr(resource_monitor, method_name):
        func = getattr(resource_monitor, method_name)
        func()
    else:
        print(f"Method not defined: {method_name}")
        sys.exit(1)