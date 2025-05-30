# SCR-BPF Transformations

This repo provides an overview on how one could create semantic patches with Coccinelle to apply SCR-aware transformations to eBPF programs.

## What is Coccinelle?
https://coccinelle.gitlabpages.inria.fr/website/ 
- Coccinelle is a program matching and transformation engine 

- Coccinelle uses semantic patches, written in the Semantic Patch Language (SmPL)
* -> Semantic patches have three main parts:
    1. Rule name, metavariable
    2. context/code patterns to match the code you are trying to transform/modify
    3. the transformation (-/+)

## What do you mean by SCR-aware? What is State-Compute Replication?
- SCR-Aware is short for State-Compute Replication Aware. So, for a program to be SCR_aware, it means that the program will have cores independently computing states when processing packets

- State-Compute Replication is a technique that states that instead of cores sharing state, each core will update the state on its own, using packet history/fast-forwarding.

- What makes a program SCR-aware follows these three main concepts:
    1. Per-core state (each core has own view of state)
    - ---> This replication allows cores to work independently. This helps to avoid contention/delays caused by waiting for other cores to access shared state. 
    2. per-packet metadata (helps update state on each core, needed for fast-forwarding)
    - ---> Track details about each packets. Each core has its own metadata for the packets it is processing, so it can keep track of them. Before a core processes a new packet, it uses the metadta to make sure it has the correct and up-to-date state. 
    3. fast-forwarding using packet history (lets each core "catch up" to the correct state)
    - ---> A process that plays the effects of previous packets, such as any updates that might have happened before it processes a new packet. 


- We are making SCR-aware transformations because eBPF programs can be written for single core execution or programs may use shared maps. So, we can create transformations where we can, for example, remove locks, replace shared state with per-core (i.e. BPF maps), etc.

# Overview:
- This repo is to showcase the exploration of some transformations; it is how we may use Coccinelle and its semantic patches in order to transform a program. 
- The key idea of using semantic patches is to be able to automate transformations without having to manually rewrite every program. However, we may still need to adjust these spatches as needed as not every program is structured the same way or they may differ in how state is handled
- The goal was to take programs and apply transformations to make it SCR-aware. 
- In this repo, some transformations may still need to be refined in order to make a fully-realized SCR-aware program, as the generated outputs you would see in the MOD dir demonstrate different stages of applying transformations, and though we may generate outputs with all spatches applied, one future direction is to be able to verify if SCR-aware is realized. 

## Challenges & Limitations:
- A single set of spatches doesn't always work for every programs (not a "one size fits all" solution). To write reusable patches, we need to deeply understand the patterns and structures of a program, as different programs can vary in things like structure and stage management. Even with generalized spatches, we may need to adjust them accordingly. 

## Future Directions
- Could focus on applying transformations for more complex programs (such as ones with more complicated state management)
- ---> apply all spatches to make a fully realized SCR-aware program
- Another area of improvement is to not only test these transformed programs to see that they work correctly and as expected after the changes are made, but also to perhaps automate that testing

## Structure of Repo
- spatch/: examples of semantic patches (spatches)
- mod/: examples of transformed programs (after a spatch was applied)
- src/: example source files to transform

## Installing and Using Coccinelle
```bash
git clone https://github.com/coccinelle/coccinelle.git
cd coccinelle
./autogen
./configure
make 
sudo make install
```

## Semantic Patch Language (SmPL)
- A semantic patch (.cocci) can have many rules 
- Coccinelle needs context. Aside from anchors, we need to explicitly declare any custom macros, attributes, etc.
- A rule can look like this:
```
@name_of_rule@
expression var;
@@
- int var = 0
+ int var = 1
```
- As you can see above, the name of the rule can be anything but it needs to be without spaces. Rules don't need to have names.
- --> Names of rules are necessary if you want to specify dependencies between rules (see below on advanced keywords)
- @@'s define the start and end of a rule.
- We can define metavariables (ex. placeholder variables which abtract over constants, expressions, identifiers, etc.), expressions (more general than identifiers), identifiers (ex. names of variables, functions, fields), declarer names, types, statements, constants, etc. in a rule, which helps Coccinelle when parsing
- --> For example, maching the use of an assignment like the int var above would need expression.
- --> It's not necessary to define every metavariable in your transformation (unless we are trying to directly match or replace it). You just need to be able to give enough context for Coccinelle to be able to parse/understand what you're trying to match and transform. Coccinelle, however, will make suggestions when applying a transformation.
- ---> By the same token, we can use ellipses (...) to abtract away code (see below):
```
@change_hash_map depends on lock_case@
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
```
- ---> Let's say we wanted to make a transformation where we replace the BPF map type. We don't care about matching anything else, such as code before or after it.
- We can also use matching condtions (!=, ==, any) (see below):
```
@@
expression E, E1;
statement S,S1;
position p1 != n.p;
@@

* E = ALLOC(...)
... when != E = E1
* if@p1 (\(E\|!E\))
 S else S1
```
- We can use disjunctions to match different patterns (see below):
```
@ao_case@
expression p, q, var;
@@ 
(
- var = __sync_fetch_and_add(p,q);
+ var = *p; 
| 
- var = __sync_fetch_and_sub(p,q);
+ var = *p; 
| 
- var = __sync_fetch_and_or(p,q);
+ var = *p; 
)
```
  
### Advanced Keywords
- We can also specify keywords for rules
- For example, we can have a rule execute only if another rule had succesfully executed. We use "depends on."
```
@num_meta@
@@
#define PORT_3 102
+ #define NUM_META 10

@depends on num_meta@
@@
src_ip = iph->saddr;
+ int index = cpu % NUM_META;
```
- --> Above: the second rule depends on the rule 'num_meta.' If num_meta is successful, then the second rule will execute.
- We can use operators such as ||, &&, etc. in combinations of our rules.
- ---> For example, if I had a rule a and rule b, and I have c, which executes if a and b were succesful, then: @@ c depends on a && b @@.

  
- These are only some parts of the SMPL grammar. For more information, check out the official Coccinelle repo/documentation.
https://github.com/coccinelle 
  
## How to apply a semantic patch
- General format:
```bash
spatch --sp-file spatchfile.cocci program.c 
```
-  --> As seen above, we apply a spatch called spatchfile.cocci onto program.c

- You can also apply a patch on a directory:
```bash
spatch --sp-file spatchfile.cocci --dir directory
```
- We can also output the transformation by:
```bash
spatch --sp-file spatchfile.cocci program.c -o output.c
```
- We could debug a failed transformation further by:
```bash
spatch --sp-file spatchfile.cocci program.c --debug 
```
## Installation
- Can use the example .sh for installation. (2 steps: ex. sh install.sh 1, sh install.sh 2). 
