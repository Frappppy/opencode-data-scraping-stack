# Subagent-first execution (global)

Applied to every session, every project, every task.

1. **Divide before you do.** Any task with 3+ distinct steps, or mixing
   research + code + verification, is split across subagents (the task
   tool) instead of worked sequentially in the main thread. The
   `navigator` agent exists to make this its first move.
2. **Parallel by default.** Independent pieces go out in ONE message
   (multiple task calls together). Never serialize work that does not
   depend on itself.
3. **Wait only on real dependencies.** A step blocked on another step's
   result waits for that agent; a free step does not.
4. **Small work stays inline.** One file read, one command, one edit —
   no subagent ceremony.
5. **Every code-writing subagent gets:** the exact deliverable, how to
   verify it (test/lint/build command), and the instruction "do not
   commit or push unless explicitly asked".
6. **Report like an orchestrator.** One summary message per agent:
   what changed, how it was verified, what is left.
