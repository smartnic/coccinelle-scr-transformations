@lock_case@
metavariable name;
@@
struct name {
    ...
- struct bpf_spin_lock lock;
};

@remove_locks depends on lock_case@
expression e;
identifier fld;
statement S1, S2;
@@
-  bpf_spin_lock(&e->fld);
   ...
-  bpf_spin_unlock(&e->fld);
 
@@
attribute name SEC;
declarer name __uint, __type;
metavariable map_name;
@@
struct{
    ...
- __uint(type, BPF_MAP_TYPE_HASH);
+ __uint(type, BPF_MAP_TYPE_PERCPU_HASH);
    ...
} map_name SEC(".maps");