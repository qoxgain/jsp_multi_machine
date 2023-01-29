"""
解决单机台单任务的模式，
即一个任务只分配到一个机台上进行作业加工
"""
import collections
# Import Python wrapper for or-tools CP-SAT solver.
from ortools.sat.python import cp_model


def jsp_process(jobs_data, result_compare=True):
    """Minimal jobshop problem."""
    # Create the model.
    model = cp_model.CpModel()
    machines_count = 1 + max(task[0] for job in jobs_data for task in job)
    all_machines = range(machines_count)
    jobs_count = len(jobs_data)
    all_jobs = range(jobs_count)

    # Compute horizon.
    horizon = sum(task[1] for job in jobs_data for task in job)

    task_type = collections.namedtuple('task_type', 'start end interval')
    assigned_task_type = collections.namedtuple('assigned_task_type',
                                                'start job index')

    # Create jobs.
    all_tasks = {}
    for job in all_jobs:
        for task_id, task in enumerate(jobs_data[job]):
            start_var = model.NewIntVar(0, horizon,
                                        'start_%i_%i' % (job, task_id))
            duration = task[1]
            end_var = model.NewIntVar(0, horizon, 'end_%i_%i' % (job, task_id))
            interval_var = model.NewIntervalVar(
                start_var, duration, end_var, 'interval_%i_%i' % (job, task_id))
            all_tasks[job, task_id] = task_type(
                start=start_var, end=end_var, interval=interval_var)

    # Create and add disjunctive constraints.
    # 代码中，使用求解器的 AddNoOverlap 方法来创建无重叠约束，从而防止同一台机器的任务在时间上重叠。
    for machine in all_machines:
        intervals = []
        for job in all_jobs:
            for task_id, task in enumerate(jobs_data[job]):
                if task[0] == machine:
                    intervals.append(all_tasks[job, task_id].interval)
        model.AddNoOverlap(intervals)

    # Add precedence contraints.
    # 添加优先级约束，防止同一作业的连续任务在时间上重叠,对于每一项工作，都要排队
    # 要求任务的结束时间发生在任务中的下一个任务的开始时间之前
    for job in all_jobs:
        for task_id in range(0, len(jobs_data[job]) - 1):
            model.Add(all_tasks[job, task_id +
                                1].start >= all_tasks[job, task_id].end)

    # Makespan objective.
    obj_var = model.NewIntVar(0, horizon, 'makespan')
    model.AddMaxEquality(
        obj_var,
        [all_tasks[(job, len(jobs_data[job]) - 1)].end for job in all_jobs])
    model.Minimize(obj_var)

    # Solve model.
    solver = cp_model.CpSolver()
    status = solver.Solve(model)

    if result_compare:
        return solver.ObjectiveValue(), round(solver.UserTime(), 2)
    print(solver.ObjectiveValue())
    if status == cp_model.OPTIMAL:
        # Print out makespan.
        # print('Optimal Schedule Length: %i' % solver.ObjectiveValue())
        # print()

        # Create one list of assigned tasks per machine.
        assigned_jobs = [[] for _ in all_machines]
        for job in all_jobs:
            for task_id, task in enumerate(jobs_data[job]):
                machine = task[0]
                assigned_jobs[machine].append(
                    assigned_task_type(
                        start=solver.Value(all_tasks[job, task_id].start),
                        job=job,
                        index=task_id))

        disp_col_width = 10
        sol_line = ''
        sol_line_tasks = ''

        # print('Optimal Schedule', '\n')

        for machine in all_machines:
            # Sort by starting time.
            assigned_jobs[machine].sort()
            sol_line += 'Machine ' + str(machine) + ': '
            sol_line_tasks += 'Machine ' + str(machine) + ': '

            for assigned_task in assigned_jobs[machine]:
                name = 'job_%i_%i' % (assigned_task.job, assigned_task.index)
                # Add spaces to output to align columns.
                sol_line_tasks += name + ' '
                start = assigned_task.start
                duration = jobs_data[assigned_task.job][assigned_task.index][1]

                sol_tmp = '[%i,%i]' % (start, start + duration)
                # Add spaces to output to align columns.
                sol_line += sol_tmp + ' '

            sol_line += '\n'
            sol_line_tasks += '\n'

        with open('machine_job_jsp.txt', 'w') as f:
            f.write(sol_line_tasks)
        with open('machine_time_jsp.txt', 'w') as f:
            f.write(sol_line)
        # print(sol_line_tasks)
        # print('Task Time Intervals\n')
        # print(sol_line)

        return solver.ObjectiveValue()

    else:
        return 1000000

if __name__ == '__main__':
    jobs_data = [
        [(0, 3), (1, 2), (2, 2)],  # Job0
        [(0, 2), (2, 1), (1, 4)],  # Job1
        [(1, 4), (2, 3)]           # Job2
    ]

    jsp_process(jobs_data, False)
