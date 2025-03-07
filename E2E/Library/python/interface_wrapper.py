from npu_cpu_memory_utilization import ResourceMonitor


# Function to create and return a ResourceMonitor instance
def get_monitor(log_folder="", duration=0):
    return ResourceMonitor(log_folder, duration)


# Define functions for external calls
def start_task_manager(monitor):
    monitor.start_task_manager()


def maximize_task_manager(monitor):
    monitor.maximize_task_manager()


def switch_to_performance_tab(monitor):
    monitor.switch_to_performance_tab()


def log_utilization(monitor, log_folder, duration):
    monitor.log_utilization(log_folder, duration)


def close_task_manager(monitor):
    monitor.close_task_manager()
