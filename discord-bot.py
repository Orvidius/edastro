#!/usr/bin/python3
#
# https://discordpy.readthedocs.io/en/latest/index.html
# https://discord.com/developers/applications/763458098346065922
# 
import discord
import random
import subprocess
import re
from discord.ext import commands
print("Starting bot...")

TOKEN = open("/home/bones/elite/token-discord.txt","r").readline()
client = commands.Bot(command_prefix = '.')

#If there is an error, it will answer with an error
@client.event
async def on_command_error(ctx, error):
	await ctx.send(f'Error. Try !help ({error})')

@client.event
async def on_ready():
	print('We have logged in as {0.user}'.format(client))


@client.event
async def on_message(message):
	if message.author == client.user:
		return

	print(message.content)

	if message.content.startswith('@edastro'):
		await message.channel.send('YES!')

	if message.content.startswith('!hello'):
		await message.channel.send('Hello!')

	if 'space' in message.content or 'Space' in message.content or 'SPACE' in message.content:
		emoji = '\N{EYES}'
		await message.add_reaction(emoji)

	if message.content.startswith('!'):
		inputstr = str(message.content)
		inputstr = re.sub(r'[^\w\d\s\!\-\':\*\+]+','',inputstr)
		print("COMMAND: " + inputstr)
		result = subprocess.run(['/home/bones/elite/bot-handler.pl', inputstr], stdout=subprocess.PIPE)
		resultstr = result.stdout.decode('utf-8');
		if len(resultstr)>0:
			print(resultstr)
			await message.channel.send(resultstr)

print("Bot is ready!")
client.run(TOKEN)
