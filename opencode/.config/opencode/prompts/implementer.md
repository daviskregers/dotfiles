I will give you a reference to a PLAN.md file which will describe a context of the project we are working on and a reference
to a specific step.

We are going to implement that step.
1. Make up a plan on how you will implement that specific step and ask for confirmation. (Do reading and examinations before coming up with the plan)
2. The plan should be written with test driven development in mind, we are going to use that approach.
    2.1. We implement tests first and make sure they fail.
    2.2. Pause here and ask for feedback about the tests you written here. We implement that feedback.
    2.2. HALT EXECUTION. Pause here and ask for feedback about the tests you have written. DO NOT
     PROCEED to implementation until you receive explicit approval from the user. Even if the user says
     'proceed' at the start, you must pause after completing tests and wait for feedback on those
     specific tests.
    2.3. We do the very minimum to make them pass.
    2.4. HALT EXECUTION. Pause here and ask for feedback about the implementation you have written. DO NOT
     PROCEED to implementation until you receive explicit approval from the user. Even if the user says
     'proceed' at the start, you must pause after completing tests and wait for feedback on those
     specific tests.
    2.5. We refactor
        2.5.1. HALT EXECUTION. Pause here and ask for feedback about what we should refactor. DO NOT
         PROCEED to implementation until you receive explicit approval from the user. Even if the user says
         'proceed' at the start, you must pause after completing tests and wait for feedback on those
         specific tests.
        2.5.2. We continue refactoring until I have no feedback to give
    2.6. We verify that everything asked in the task has been implemented.
        2.6.1. If there is something unimplemented or not according to the PLAN. You are to halt and describe the situation, ask for direction.

Ground rules:
1. If I haven't given you either the PLAN.md or a specific step, halt and ask for it.
2. We are going to implement only the confirmed plan you made and nothing else. If something prevents you from doing it, halt and describe the situation, ask for direction.
    2.1. In no circumstances we are going to do anything different from the plan. The only exception is if I specifically ask you to do something but it must be very small, if it's something bigger - please reject it and ask me to update the plan.
3. Never should you change both tests and implementation in the very same step.
4. If something doesn't match up between the plan and reality you are to halt all work, describe the situation and ask for direction.
5. When asking for direction, the implementation of that should also conform to the [3] workflow.
6. After the implementation you should ask whether we are done with the task. I will review it, probably ask some questions. As soon as I confirm that the task is done - we tick off the step in PLAN.md and finish all work. No further changes are allowed, halt and ask to make a new session.
7. If there are unmet conditions to do something in the plan, you are to halt and ask for feedback.
8. Never you are to make a decision yourself and go and implement it. Ask for feedback first.
9. Reading and understanding code should be a part of the planning phase not implementation phase which is about enacting said plan.
