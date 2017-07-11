# Apollo Kernel

The Apollo Kernel provides the necessary kernel level support to run Apollo software stack.
In the first release, we add the most popular solution, Linux Kernel, under the linux directory.

## Linux Kernel

Apollo Linux Kernel is based on official [Linux Kernel 4.4.32](https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.4.32.tar.gz) with some modifications.

### What is the difference

  * Realtime patch (https://rt.wiki.kernel.org/index.php/RT_PREEMPT_HOWTO)
  * Latest e1000e intel ethernet driver
  * Bugfix for Nvidia driver under realtime patch
  * Double free in the inet_csk_clone_lock function patch (https://bugzilla.redhat.com/show_bug.cgi?id=1450972)
  * Other cve security patches

[Kernel config files](https://github.com/ApolloAuto/apollo-kernel/tree/master/linux/configs) are modified for Apollo based on Ubuntu's config-4.4.0-X-generic.

The Apollo team would like to thank everybody in the open source community. The GitHub apollo-kernel/linux is based on Linux. Currently, Apollo team maintains this repository. In near future, we’ll send patches back to Linux community.

### Add ESD CAN Support

You will need to add ESD CAN driver to run Apollo software using ESD CAN card. Please refer to linux/ESDCAN-README.md for more information.

### How to Download the Release Package

Download the release packages from the release section on github:

```
https://github.com/ApolloAuto/apollo-kernel/releases
```

### How to Install

After having the release package downloaded:

```
tar zxvf linux-4.4.32-apollo-1.0.0.tar.gz
cd install
sudo ./install_kernel.sh
```

### How to Build


If you would like cutomize and build your own kernel, simply run:

```
./build.sh
```

You can find the installation kernel package under directory:

```
./install/rt
```

### Realtime "Hello World" Example
(https://rt.wiki.kernel.org/index.php/RT_PREEMPT_HOWTO#A_Realtime_.22Hello_World.22_Example)

* Setting a real time scheduling policy and priority
* Locking memory so that page faults caused by virtual memory will not undermine deterministic behavior
* Pre-faulting the stack, so that a future stack fault will not undermine deterministic behavior

The following example contains some very basic example code of a real time application with realtime preemption patch. Compile as follows:
```
gcc -o test_rt test_rt.c -lrt
```

Source code as below:
```
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <sched.h>
#include <sys/mman.h>
#include <string.h>

#define MY_PRIORITY (49) /* we use 49 as the PRREMPT_RT use 50
                            as the priority of kernel tasklets
                            and interrupt handler by default */

#define MAX_SAFE_STACK (8*1024) /* The maximum stack size which is
                                   guaranteed safe to access without
                                   faulting */

#define NSEC_PER_SEC    (1000000000) /* The number of nsecs per sec. */

void stack_prefault(void) {

        unsigned char dummy[MAX_SAFE_STACK];

        memset(dummy, 0, MAX_SAFE_STACK);
        return;
}

int main(int argc, char* argv[])
{
        struct timespec t;
        struct sched_param param;
        int interval = 50000; /* 50us*/

        /* Declare ourself as a real time task */

        param.sched_priority = MY_PRIORITY;
        if(sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
                perror("sched_setscheduler failed");
                exit(-1);
        }

        /* Lock memory */

        if(mlockall(MCL_CURRENT|MCL_FUTURE) == -1) {
                perror("mlockall failed");
                exit(-2);
        }

        /* Pre-fault our stack */

        stack_prefault();

        clock_gettime(CLOCK_MONOTONIC ,&t);
        /* start after one second */
        t.tv_sec++;

        while(1) {
                /* wait until next shot */
                clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &t, NULL);

                /* do the stuff */

                /* calculate next shot */
                t.tv_nsec += interval;

                while (t.tv_nsec >= NSEC_PER_SEC) {
                       t.tv_nsec -= NSEC_PER_SEC;
                        t.tv_sec++;
                }
   }
}
```

### Disclaimer
The patched Linux kernel is specifically for running Apollo software stack on an Apollo 1.0 Reference Hardware Platform (see [*Apollo 1.0 Hardware and System Installation Guide*](https://github.com/ApolloAuto/apollo/blob/master/docs/quickstart/apollo_1_0_hardware_system_installation_guide.md) for more information). It is not recommended for any other purposes.
