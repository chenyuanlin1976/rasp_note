# Virtual A/B

Virtual A/B is Android's modern Over-The-Air (OTA) update mechanism.  
It bridges the gap between traditional A/B (seamless) updates and non-A/B updates, aiming to give users the best of both worlds:  
zero-downtime background updates with safety rollbacks, but without requiring an entire duplicate set of system partitions  
that waste precious storage space.

The "swap" and background mechanisms work through a clever combination of  
**Virtual Partitions, Copy-on-Write (COW), and Snapshot Merging**.

## 1. The Problem with Traditional A/B vs. Non-A/B

+ Non-A/B (Traditional): Had only one set of system partitions.  
  Updates were applied while the phone was offline (in Recovery mode),  
  leaving the device unusable for minutes. If it failed, the phone could brick.
+ Traditional A/B: Maintained 2 complete sets of physical slots (_a and _b).  
  The system updated the inactive slot in the background, and on reboot, it simply "swapped" the active slot pointer.  
  While extremely safe and seamless, it wasted gigabytes of storage just to keep a duplicate OS image sitting idle.

## 2. How Virtual A/B Works (The "No-Second-Slot" Illusion)

Virtual A/B eliminates the need for a physical second slot. Instead, when an update is downloaded:

+ Writing to Snapshots (COW): The new OS files aren't written to a brand-new physical partition.  
  Instead, they are written into a COW (Copy-On-Write) snapshot device.  
  The COW file only stores the differences (deltas) or compressed blocks between the old system and the new system.
+ The Swap/ Boot Process: When you reboot your phone after downloading an update,  
  the bootloader is tricked into mounting the base system combined with the new snapshot data  
  using Linux device-mapper layers (dm-linear and dm-user). 

## 3. The "Swap" & Rollback Safety Net

Because there isn't a physical second slot to swap to instantly, the transition relies on a smart state machine handled by Android's update_engine and boot control HAL:

+ If the boot fails: If the new OS crashes during startup or fails to pass health checks,  
  the bootloader automatically detects the failure, discards the snapshot, and rolls back to the original base system seamlessly.
+ If the boot succeeds: Once the device boots up successfully and stability is verified, the system initiates a Snapshot Merge process.

## 4. The Background Merge Process

After a successful boot, the changes aren't immediately merged.  
Running a background daemon called snapuserd (supported by userspace block drivers):

+ Gradually copies and writes the snapshot data back into the base physical partition in the background while you use the phone.   
+ Once the merge is fully complete, the snapshot file is deleted,  
  and the storage space is reclaimed, leaving the device running a unified, updated single set of partitions.

## Summary of Benefits

+ Space-Saving: Saves gigabytes of storage compared to standard A/B partitions  
  because it only stores block-level changes rather than a full second OS image.
+ Seamless: Updates happen completely in the background while the phone is powered on and running normally.
+ Safe (Auto-Rollback): If an update goes wrong, the device reverts automatically without locking you out or bricking.
