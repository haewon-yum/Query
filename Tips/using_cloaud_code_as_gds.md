# Slide 1: Intro
- I want to share how I'm using AI Agent (primarily with Claude Code)
- This is not an answer or something you need to follow, just hoping this is helpful as a piece of information when you're working with AI Agent. 
- Also I want to learn from everyone on team, so hope we have take some time going forward during our weekly sync to share each individual's learnings on AI. 

# Slide 2: What is Claude Code
- Let me go over this page quickly 
- Quick intro, self intro written by Claude code. 
- This is Agent, so it chooses the tool to leverage to answer the question. 

# Slide 3: Environment Architecture
- This is my current working environment
- I have my root workspace named Queries, (becuase originally this was my own query repo)
- It has 2 Claude.md file
    - one for global instructuion including my person and general principles of conducting analysis
    - The other for project level guide with more specific rules, such as jupyter notebook template, caveats of BQ tables, etc. 
- I have sub-agents, but two agents built by Eng team - Mobius and BQ Agent seem to be use most time. 
- 19 skills, which I will walk through later. 
- MCP connections
- Memories, maintained locally, and I want to know how locally saved memories could be intengrated somhow back to Moloco-wide Agents such as Searchlight or BQ Agent. 
- Hooks - still I'm not really familiar with hooks. so let me skip explanations on them. 
- I also downloaded marketplace which is skill plugin, but not yet installed. This is something I'll try going forward. 
- Lastly, I use Searchlight by invoking it through bash command from my current workspace. Instructions on how to use searchlight is included in claude.md. 
- Let me go over each component. 

# Slide 4: Component Guide (1/2)
- Two CLAUDE.md
- Skills cover several areasl such as investigation, campaign information, productivity, dev related. 
- Let me introduce some I frequently use later. 
- I have 4 agents

# Slide 5: Component Guide (2/2)
- 6 MCP connection -- let me know if there're any other MCPs useful to connect!
- I have 7 files for memory. I've tried to save back to my memory whenever I figured out reapated mistakes by Claude. 

# Slide 6: BQ Agent vs Searchlight - Why different? 
- just for someone who may have a question. Why BQ Agent is registered as subagent, but Searchlight is not?
    - BQ agent can be invoked in my current claude session, it is designed to be used in that way, 
    - However searchlight is using its own MCP connection, so new Claude session for searchlight should be opened. So it is unable to use within the current session. 

# Slide 7: Skills
- I've create several custom skills, by creating new command called new-command which helps to create a new skill, which is Simon shared with us in the slack channel. 
    - Many of them are under productivity bucket. 
- Highlighted skills are those I use frequently. 
    - for example, weekly-summary is for summarizing my activities on Slack or gDrive and who mentioned me for what, and if there're pending action items I need to follow-up on, unaswered DM, etc. 
    - It is very useful especially on Monday!
- Notify is for sending analysis result to my Slack

# Slide 8: example of skill 
- Quickly go over

# Slie 9: Two Ways to Work with Claude Code
- So far I went over my working environment. 
- Now I want to share how I use them. 
- Overall, there are two ways to work with claude code. 
    - First pattern is deep-dive with exploration. Clearing each hypothesis, followed by building new hypothesis. 
        - For example, there is a VT related analysis in Korea to build customer facing narratives when VT related concerns araise.  
        - I valiated with my first hypotheses in notebook environment with prompting in the Claude session
        - Claude wrote the queries to validate and draw charts
        - I intereven time to time to valiate the result, and create a new hypotheses based on the findings. 
        - This is an interative process. 
    - Second pattern is more end-to-end task in case it is structure d, bounded tasks with a clear start and finish.
        - for example, quick investigation for the jira ticket, with Searchlight I can do a quick analysis for the first draft, and conduct follow-up questions to the given draft. 

        
# Slide 10-12: 
- Slide 10 to 14 is exmple with my actual prompt. 
    - for the pattern 1, I'm usually working with jupyter notebook, doing back and forth interations to build upon the previous findings.
    -
# Slide 13-14
- For a ticket work, I delegated end-to-end analysis to the Searchlight for the first draft. 
- After the work done, if I need further artifacts I pulled queries or drew charts to be shared. 

# Slide 15
- I may skip this. 

# Slide 16: Jupyter MCP
- As a usuful MCP, Jupyter MCP enable claude code to run Jupyter kernel and executes code directly. It is usuful whever we need queries or charts populated in the notebook, in addition to final outputs. 

# Slide 17: CLAUDE.md vs Memory
- Just as a reference, this is diferrence between CLAUDE and Memory. 
    - CLAUDE md is not evolving unless we directly modify the instructions. 
    - While memory is more about evolving knowledge base. 
        - Claude writes it automatically when something worth keeping surfaces. You also explicitly guide Claude to save something to the memory. 

# Slide 18: Key Skills & BQ Knowlege Built
- this is an example of what saved in the memory. 