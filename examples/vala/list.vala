public static string level_name (Distinst.LogLevel level) {
    switch(level) {
    case Distinst.LogLevel.TRACE:
        return "Trace";
    case Distinst.LogLevel.DEBUG:
        return "Debug";
    case Distinst.LogLevel.INFO:
        return "Info";
    case Distinst.LogLevel.WARN:
        return "Warn";
    case Distinst.LogLevel.ERROR:
        return "Error";
    default:
        return "Unknown";
    }
}

public static int main (string[] args) {
    Distinst.log((level, message) => {
        stderr.printf ("Log: %s %s\r\n", level_name (level), message);
    });

    Distinst.Disks disks = Distinst.Disks.probe ();
    foreach (unowned Distinst.Disk disk in disks.list()) {
        uint8[] disk_path = disk.get_device_path();
        uint64 disk_sectors = disk.get_sectors();
        uint64 disk_sector_size = disk.get_sector_size();
        uint64 disk_size = disk_sectors * disk_sector_size;

        stdout.printf(
            "%.*s: %lu * %lu = %lu MB\n",
            disk_path.length,
            (string) disk_path,
            disk_sectors,
            disk_sector_size,
            disk_size/1000000
        );

        foreach (unowned Distinst.Partition partition in disk.list_partitions()) {
            uint8[] part_path = partition.get_device_path();
            uint64 part_start = partition.get_start_sector();
            uint64 part_end = partition.get_end_sector() + 1;
            uint64 part_sectors = part_end - part_start;
            uint64 part_size = part_sectors * disk_sector_size;

            stdout.printf(
                "  %.*s: %lu - %lu = %lu * %lu = %lu MB\n",
                part_path.length,
                (string) part_path,
                part_end,
                part_start,
                part_sectors,
                disk_sector_size,
                part_size/1000000
            );
        }
    }

    return 0;
}
