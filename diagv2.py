import os
import time
import re
import matplotlib.pyplot as plt
from datetime import datetime

# Define the log file path
log_file_path = input("Enter the path to the log file: ")

# Output separators
print("\n" + "="*30 + "\n")

print("DIAGNOSTICS REPORT")
print("Input service log : " + log_file_path)

# Output separators
print("\n" + "="*30 + "\n")

# Define the messages to flag
flagged_messages = [
    # "cam",
    # "CM0"
]

# Define important standard messages which should be there always
should_be_th_messages = [
    # Camera initialization messages
    "CAM: Number of GPhoto cameras: 1",
    "CAM: Starting first capture of Gphoto camerausb:002,002",
    "CAM: Gphoto first capture error is No error",
    "CAM: Gphoto second capture error is No error",
    "CAM: Camera configuration is saved"
]

# Define error messages
error_messages = [
    "NAV: NavSolver was notified 2 times already - must have been too busy!",
    "Time is not valid",
    "SCN: Livox broadcast received - resetting state",
    "CORR:",
    "bytes is discarded to avoid buffer overflow!",
    "SCN: LARGE latency =",
    "CM0: Camera #0 failed!",
    "CAM: Gphoto second capture error is I/O problem",
    "SCN: Failed to connect to Hesai tcp interface!",
    "RCV: invalid PPS clear file",
    "SCN: LARGE MICROSEC GAP",
    "SCN: TIME REVERSAL",
    "IMU: IMU data timeout",
    "No traffic from receiver"
]

# Function to read and process the log file
def process_log_file(file_path, flagged_messages, should_be_th_messages, error_messages):
    found_messages = set()
    error_found = False
    temperatures = []
    temp_timestamps = []
    queue_sizes = []
    queue_timestamps = []
    logging_start_time = None
    logging_end_time = None
    output_lines = ["\n" + "="*30 + "\n DIAGNOSTICS REPORT\n" + "="*30 + "\n",
                   "Input service log : " + log_file_path,
                   ]

    with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
        for line in file:
            for message in flagged_messages:
                if message in line:
                    output_lines.append("Flagged Message: " + line.strip())
                    print("\033[1mFlagged Message:\033[0m", line.strip())

    output_lines.append("\n" + "="*30 + "\n")
    print("\n" + "="*30 + "\n")
    
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
        for line in file:
            for th_message in should_be_th_messages:
                if th_message in line:
                    found_messages.add(th_message)
                    print(th_message)

            for error_message in error_messages:
                if error_message in line:
                    output_lines.append("Error Message: " + line.strip())
                    print("\033[1mError Message:\033[0m", line.strip())
                    error_found = True

            # Extract temperature values and their timestamps
            temp_match = re.search(r"(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}\.\d{6,9}) SCN: LiDAR scanner temperature is (\d+\.\d+) deg C", line)
            if temp_match:
                timestamp_str = temp_match.group(1)
                temperature = float(temp_match.group(2))
                try:
                    # Trim timestamp to first 6 digits of microseconds
                    if len(timestamp_str.split(".")[1]) > 6:
                        timestamp_str = timestamp_str[:-3]
                    # Convert timestamp to a datetime object
                    timestamp = datetime.strptime(timestamp_str, "%Y-%m-%d-%H-%M-%S.%f")
                    # Ignore temperature messages with the year 2022
                    if timestamp.year == 2022:
                        continue
                    temperatures.append(temperature)
                    temp_timestamps.append(timestamp)
                except ValueError as e:
                    print(f"Error parsing timestamp {timestamp_str}: {e}")

            # Extract queue size values and their timestamps
            queue_match = re.search(r"(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}\.\d{6,9}) .* Queue size = (\d+)", line)
            if queue_match:
                timestamp_str = queue_match.group(1)
                queue_size = int(queue_match.group(2))
                try:
                    # Trim timestamp to first 6 digits of microseconds
                    if len(timestamp_str.split(".")[1]) > 6:
                        timestamp_str = timestamp_str[:-3]
                    # Convert timestamp to a datetime object
                    timestamp = datetime.strptime(timestamp_str, "%Y-%m-%d-%H-%M-%S.%f")
                    queue_sizes.append(queue_size)
                    queue_timestamps.append(timestamp)
                except ValueError as e:
                    print(f"Error parsing timestamp {timestamp_str}: {e}")

            # Extract logging start and end times
            logging_start_match = re.search(r"(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}\.\d{6,9}) .*KRN: Logging to", line)
            if logging_start_match:
                logging_start_time_str = logging_start_match.group(1)
                try:
                    if len(logging_start_time_str.split(".")[1]) > 6:
                        logging_start_time_str = logging_start_time_str[:-3]
                    logging_start_time = datetime.strptime(logging_start_time_str, "%Y-%m-%d-%H-%M-%S.%f")
                except ValueError as e:
                    print(f"Error parsing logging start timestamp {logging_start_time_str}: {e}")

            logging_end_match = re.search(r"(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}\.\d{6,9}) .*KRN: Stopped logging", line)
            if logging_end_match:
                logging_end_time_str = logging_end_match.group(1)
                try:
                    if len(logging_end_time_str.split(".")[1]) > 6:
                        logging_end_time_str = logging_end_time_str[:-3]
                    logging_end_time = datetime.strptime(logging_end_time_str, "%Y-%m-%d-%H-%M-%S.%f")
                except ValueError as e:
                    print(f"Error parsing logging end timestamp {logging_end_time_str}: {e}")

    output_lines.append("\n" + "="*30 + "\n")
    print("\n" + "="*30 + "\n")
    
    if not error_found:
        output_lines.append("No error found")
        output_lines.append("\n" + "="*30 + "\n")
        print("\033[1mNo error found\033[0m")
        print("\n" + "="*30 + "\n")

    # Check for missing messages
    missing_messages = set(should_be_th_messages) - found_messages
    if missing_messages:
        output_lines.append("Error Found : Missing Messages:")
        print("\033[1mError Found : Missing Messages:\033[0m")
        for missing_message in missing_messages:
            output_lines.append(missing_message)
            print(missing_message)
    else:
        output_lines.append("No Missing Standard Messages")
        print("\033[1mNo Missing Standard Messages\033[0m")

    # Output separators before logging search output
    output_lines.append("\n" + "="*30 + "\n")
    print("\n" + "="*30 + "\n")

    # Calculate logging time
    if logging_start_time and logging_end_time:
        logging_duration = (logging_end_time - logging_start_time).total_seconds()
        output_lines.append(f"Logging time in seconds: {logging_duration:.2f}")
        print(f"\033[1mLogging time in seconds:\033[0m {logging_duration:.2f}")
    else:
        output_lines.append("Logging start or end time not found.")
        print("\033[1mLogging start or end time not found.\033[0m")

    # Output separators
    output_lines.append("\n" + "="*30 + "\n")
    print("\n" + "="*30 + "\n")

    return output_lines, temperatures, temp_timestamps, queue_sizes, queue_timestamps

# Generate timestamp for the file
timestamp = time.strftime("%Y%m%d%H%M%S")
output_directory = os.path.dirname(log_file_path)
output_filename = os.path.join(output_directory, f"diagnostics_report_{timestamp}.txt")

# Call the function to process the log file
output_content, temperatures, temp_timestamps, queue_sizes, queue_timestamps = process_log_file(log_file_path, flagged_messages, should_be_th_messages, error_messages)

# Save the final output to a file
with open(output_filename, 'w') as output_file:
    output_file.write("\n".join(output_content))

print(f"Diagnostic report saved as {output_filename}")

# Plot the temperatures
if temperatures and temp_timestamps:
    plt.figure(figsize=(10, 6))
    plt.plot(temp_timestamps, temperatures, marker='o')
    plt.title('LiDAR Scanner Temperature Over Time')
    plt.xlabel('Time')
    plt.ylabel('Temperature (deg C)')
    plt.grid(True)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(os.path.join(output_directory, f"temperature_plot_{timestamp}.png"))
    plt.show()
else:
    print("No temperature data found.")

# Plot the queue sizes
if queue_sizes and queue_timestamps:
    plt.figure(figsize=(10, 6))
    plt.plot(queue_timestamps, queue_sizes, marker='o', color='r')
    plt.title('Queue Size Over Time')
    plt.xlabel('Time')
    plt.ylabel('Queue Size')
    plt.grid(True)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(os.path.join(output_directory, f"queue_size_plot_{timestamp}.png"))
    plt.show()
else:
    print("No queue size data found.")
