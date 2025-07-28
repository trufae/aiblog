# Prompt Engineering

## Least-To-Most

This process helps in teaching the AI model to better understand and respond to the user’s needs by starting with minimal guidance and progressively adding more detailed instructions.

* Create a travel itinerary for a week in Japan
* Create a travel itinerary for a week in Japan, including visits to Tokyo, Kyoto, and Osaka
* Create a travel itinerary for a week in Japan, visiting Tokyo, Kyoto, and Osaka. Include cultural sites, local food experiences, and popular tourist attractions.
* Create a travel itinerary for a week in Japan, visiting Tokyo, Kyoto, and Osaka. For each city, include one cultural site, one local restaurant, and one popular tourist attraction per day.

## Self-Ask

By incorporating self-ask prompting, the AI can better emulate human problem-solving processes, leading to improved interaction quality and user satisfaction.

* Use self-ask prompting to help me plan a one-week vacation in Italy

## Meta-Prompting

Encourages the AI to outline a strategy before diving into the task, leading to more structured and coherent responses. Helps in breaking down complex tasks into manageable steps, ensuring all aspects are covered. Results in more detailed and accurate outputs by addressing potential gaps in understanding from the outset.

1.	Initial Meta Prompt: The AI is prompted to consider how to approach the task.
2.	Strategy Formation: The AI outlines a plan or strategy for addressing the task.
3.	Execution: The AI then follows the strategy to generate the final response.

Example:

* Before writing the essay, think about the key points and structure needed to effectively address the impacts of climate change on coastal cities.
* Great, now use that plan to write the essay.

## Chain-Of-Thought

The AI model is guided to articulate its reasoning process step-by-step as it works towards a solution. This approach helps the model generate more accurate and coherent responses by explicitly breaking down the problem into smaller, manageable parts and reasoning through them sequentially.

Append "explain your reasoning step by step". 

Example

* Calculate the area of a circle with a radius of 7 cm. Explain your reasoning step by step

## ReAct

ReAct is a technique that uses natural language processing (NLP) and machine learning algorithms to generate human-like responses.

This method involves the AI model breaking down a complex problem into smaller steps, reasoning about each step, and then taking actions based on its reasoning. The process iterates until the task is completed. This approach ensures that the AI model not only considers the problem logically but also adapts its actions based on intermediate results.

https://cobusgreyling.medium.com/react-synergy-between-reasoning-acting-in-llms-36fc050ae8c7

* Author David Chanoff has collaborated with a U.S. Navy admiral who served as the ambassador to the United Kingdom under which President?

## Symbolic Reasoning & PAL

LLMs should not only be able to perform mathematical reasoning, but also symbolic reasoning which involves reasoning pertaining to colours and object types.

https://cobusgreyling.medium.com/symbolic-reasoning-pal-program-aided-large-language-models-d1910215a040

* I have a chair, two potatoes, a cauliflower, a lettuce head, two tables, a cabbage, two onions, and three fridges. How many vegetables do I have?
* how many furnitures?

## Iterative Prompting

Instead of expecting a perfect answer from a single prompt, the user provides feedback or additional prompts to iteratively improve the quality and accuracy of the AI’s output. This method allows for progressive enhancement and fine-tuning of the response, ensuring it meets the desired criteria.

* Write an introduction for a report on renewable energy sources.
* Can you include specific examples of renewable energy sources and mention the importance of addressing climate change?
* Expand on the economic benefits of renewable energy sources.
* Mention the role of government policies in promoting renewable energy

## Sequential Prompting

The AI is guided through a series of prompts in a logical sequence to progressively build a comprehensive and detailed response.

* Plan a multi-day hiking trip in the Rocky Mountains.
* Intermediate trails, please
* I plan to hike for 4 days.
* Yes, please include a packing list

**Key Differences**

1.	Purpose:
	•	Sequential Prompting: Focuses on systematically developing a response by addressing different aspects of the task in order.
	•	Iterative Prompting: Focuses on refining and improving a response through feedback and continuous enhancement.
2.	Process:
	•	Sequential Prompting: Moves forward with new prompts addressing new aspects of the task.
	•	Iterative Prompting: Moves in a feedback loop, refining the same aspect or response multiple times.
3.	Use Case:
	•	Sequential Prompting: Best for tasks that can be broken down into distinct, logical steps (e.g., planning an event, creating a structured outline).
	•	Iterative Prompting: Best for tasks that benefit from refinement and detailed enhancement (e.g., writing, complex problem solving).


## Self-Consistency

Ensures that the most reliable and accurate information is highlighted by cross-referencing multiple responses. Produces a final output that is coherent and internally consistent. Reduces the impact of any single erroneous or biased response by considering multiple perspectives.

Useful for Summarization, Problem-Solving and Creative Writing.

The AI will provide multiple possible responses for a single question and reason which one makes more sense.

* Summarize the key points of a research article on climate change impacts.

## Automatic Reasoning & Tool Use (ART)

Leverages external tools to perform accurate and reliable calculations or data retrieval. Automates complex tasks by seamlessly integrating reasoning with tool usage. Extends the functionality of AI models to handle a wider range of tasks and queries.

* Calculate the monthly mortgage payment for a $300,000 loan with an interest rate of 4% over 30 years. Explain the process
* Extract using JSON format: the topic, key words and details from this question: "what's the weather in tokyo for tomorrow?"
* Please respond using ONLY in JSON providing topic, location, url, name, description, target, amounts and other details if necessary without providing any response: Question: "..."

## Zero-Shot Prompting

The user provides a task description without any examples or specific context. The AI generates a response based on its general understanding and knowledge.

* Translate the following sentence from English to Spanish: ‘The weather is beautiful today.’

## Few-Shot Prompting

The user provides a task description along with a few examples to illustrate what is expected. The AI uses the provided examples to infer the task requirements and generate a relevant response.

* Translate the following sentences from English to Spanish: ".. (provide some examples.. of english->english sentences, ) Now, translate this sentence: "We are traveling to Spain next month"

## Generated Knowledge Prompting

This method allows the AI to build a foundation of knowledge before tackling a more complex prompt, resulting in a more coherent and comprehensive response.

* Explain the key effects of climate change on marine life.
* Using the information provided, write an essay on the impact of climate change on marine life.

## Prompt Chaining

This approach of prompt chaining allows the AI to progressively build and refine its response, ensuring a comprehensive and detailed final output.

* List and briefly describe different types of renewable energy sources.
* What are the benefits of using these renewable energy sources?
* Discuss the challenges associated with implementing renewable energy sources.
* Combine the information from the previous responses into a comprehensive report on renewable energy, including types, benefits, and challenges

## Tree of Thoughts (ToT)

The user provides a broad task or problem. The AI generates multiple potential approaches or solutions, creating a “tree” of possible thoughts. The AI evaluates the different branches to determine the best course of action. The AI synthesizes the best branches into a coherent response.

Tree of Thoughts Prompting enables the AI to think critically and creatively, exploring various possibilities and combining the best ideas into a cohesive strategy. This method is particularly useful for complex problems that benefit from multi-faceted solutions.

* Develop a strategy to reduce plastic waste in a city.

## Retrieval Augmented Generation (RAG)

Pull data from the internet and provide the context to the query to be able to show proper response

* Write a detailed report on the latest advancements in renewable energy technologies.

## Automatic Prompt Engineer (APE)

Automatic Prompt Engineer (APE) is an AI system designed to automatically generate, refine, and optimize prompts for other AI models. The goal of APE is to create effective prompts that maximize the performance and accuracy of the AI model’s responses. APE systems use various techniques such as machine learning, natural language processing, and feedback loops to iteratively improve prompts based on their performance.

* Use Automatic Prompt Engineering to answer "why the sky is blue" and choose the best one for me
* Use Automatic Prompt Engineering to answer the following question and choose the best question for me: "who is the author of radare2"

## Active-Prompt

Allows for real-time adjustments based on the AI’s responses, leading to more precise and relevant information. Each step refines the previous one, ensuring a more comprehensive and accurate output. Facilitates a more interactive and engaging conversation with the AI, making it suitable for complex or detailed inquiries.

* How does climate change affect polar bears?
* Can you explain how the reduction in sea ice affects their hunting habits and survival?
* What are the long-term effects on polar bear populations due to these changes in their hunting habits?

## Directional Stimulus Prompting

Directs the AI to concentrate on specific aspects of a broader topic, ensuring the response aligns with the user’s interests. Encourages more detailed and in-depth responses by narrowing down the scope of the prompt. Enhances the relevance of the AI’s output to the user’s needs by providing clear guidance on the desired focus area.

* Describe the economic impacts of renewable energy adoption.
* Focus on the job creation aspect and provide detailed examples of how renewable energy projects have created jobs in different sectors

## PAL (Program-Aided Language Models)

An approach that integrates the capabilities of programming and computational tools with language models to enhance their performance in solving complex problems.

By leveraging programming languages or scripts, PAL can handle tasks that require precise calculations, data manipulation, or algorithmic processes, which are beyond the direct capabilities of language models alone.

User makes a question that triggers the model to write a script in Python that when executed give the answer

* Calculate the trajectory of a projectile with an initial speed of 50 m/s and an angle of 30 degrees. Explain the process.

## Reflexion

Reflexion is designed to help agents improve their performance by reflecting on past mistakes and incorporating that knowledge into future decisions. This makes it well-suited for tasks where the agent needs to learn through trial and error, such as decision-making, reasoning, and programming.

Helps the AI refine its responses by learning from previous outputs.

* Write a short story about a time-traveling explorer.
* Reflect on the initial story. Identify areas that could be expanded or improved for better engagement and detail.
* Rewrite the story, incorporating your reflections for better detail and engagement.

## Multimodal CoT Prompting

Combines different types of information (images, graphs, text) to provide a holistic analysis. Improves the AI’s ability to reason through complex problems by considering multiple data sources. Ensures that the final output is detailed, accurate, and considers various aspects of the problem.

* uses text, images, sounds as input

# Sources

These links were used as source of inspiration

* https://cobusgreyling.medium.com/12-prompt-engineering-techniques-644481c857aa
* https://www.promptingguide.ai
