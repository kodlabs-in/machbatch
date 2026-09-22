extension SQLiteJobStore {
  static let schema = """
    CREATE TABLE IF NOT EXISTS schema_migrations(
        version INTEGER PRIMARY KEY,
        applied_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS physical_hosts(
        id INTEGER PRIMARY KEY,
        hostname TEXT NOT NULL,
        architecture TEXT NOT NULL,
        cpu_slots INTEGER NOT NULL,
        memory_mib INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS logical_nodes(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        cpu_slots INTEGER NOT NULL,
        memory_mib INTEGER NOT NULL,
        state TEXT NOT NULL,
        reason TEXT
    );
    CREATE TABLE IF NOT EXISTS partitions(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        is_default INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS jobs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        user_name TEXT NOT NULL,
        partition_name TEXT NOT NULL,
        command_json TEXT NOT NULL,
        cpu_slots INTEGER NOT NULL CHECK(cpu_slots > 0),
        memory_mib INTEGER NOT NULL CHECK(memory_mib > 0),
        wall_time_seconds INTEGER NOT NULL CHECK(wall_time_seconds > 0),
        state TEXT NOT NULL,
        submitted_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS job_steps(
        id INTEGER PRIMARY KEY,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        state TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS job_tasks(
        id INTEGER PRIMARY KEY,
        step_id INTEGER NOT NULL REFERENCES job_steps(id),
        rank INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS allocations(
        id INTEGER PRIMARY KEY,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS resource_ledger(
        job_id INTEGER PRIMARY KEY REFERENCES jobs(id),
        cpu_slots INTEGER NOT NULL,
        memory_mib INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS job_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        previous_state TEXT,
        new_state TEXT NOT NULL,
        actor TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
    CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
    CREATE TABLE IF NOT EXISTS associations(
        id INTEGER PRIMARY KEY,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        user_id INTEGER NOT NULL REFERENCES users(id)
    );
    CREATE TABLE IF NOT EXISTS qos(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, limits_json TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS usage_samples(
        id INTEGER PRIMARY KEY,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        sampled_at REAL NOT NULL,
        resident_memory_bytes INTEGER,
        cpu_seconds REAL
    );
    CREATE TABLE IF NOT EXISTS usage_rollups(
        id INTEGER PRIMARY KEY,
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        values_json TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS dependencies(
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        dependency_job_id INTEGER NOT NULL REFERENCES jobs(id),
        kind TEXT NOT NULL,
        PRIMARY KEY(job_id, dependency_job_id, kind)
    );
    CREATE TABLE IF NOT EXISTS array_elements(
        job_id INTEGER NOT NULL REFERENCES jobs(id),
        task_index INTEGER NOT NULL,
        state TEXT NOT NULL,
        PRIMARY KEY(job_id, task_index)
    );
    CREATE TABLE IF NOT EXISTS generic_resources(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        total INTEGER NOT NULL,
        allocated INTEGER NOT NULL,
        properties_json TEXT NOT NULL
    );
    """
}
