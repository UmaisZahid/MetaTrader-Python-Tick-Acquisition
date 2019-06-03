"""
    Python Client Connector V1.py
    --
    @author: Umais Zahid (umais.me)

    Copyright (c) 2019, Umais Zahid. All rights reserved.
"""

##########################
# Import statements      #
##########################
import random
import timeit

import zmq
from time import sleep
from pandas import DataFrame, Timestamp, Timedelta, Series
from threading import Thread
import pandas as pd


####################################
# MTConnector Class Definition     #
####################################
class MTConnector():

    def __init__(self,
                 CLIENT_ID='PythonClient1',  # Unique ID for this client
                 HOST='localhost',  # Host to connect to
                 PROTOCOL='tcp',  # Connection protocol
                 PUSH_PORT=32768,  # Port for Sending commands
                 PULL_PORT=32769,  # Port for Receiving responses
                 SUB_PORT=32770,  # Port for Subscribing for prices
                 VERBOSE=True):  # Determines whether statements should be printed

        # Strategy Status (if this is False, ZeroMQ will not listen for data)
        self.ACTIVE = True

        # Client ID
        self.CLIENT_ID = CLIENT_ID

        # ZeroMQ Host
        self.HOST = HOST

        # Connection Protocol
        self.PROTOCOL = PROTOCOL

        # Initialise ZeroMQ Context
        self.ZMQ_CONTEXT = zmq.Context()

        # TCP Connection URL Template
        self._URL = self.PROTOCOL + "://" + self.HOST + ":"

        # Ports for PUSH, PULL and SUB sockets respectively
        self.PUSH_PORT = PUSH_PORT
        self.PULL_PORT = PULL_PORT
        self.SUB_PORT = SUB_PORT

        # Create Sockets
        self.PUSH_SOCKET = self.ZMQ_CONTEXT.socket(zmq.PUSH)
        self.PUSH_SOCKET.setsockopt(zmq.SNDHWM, 1)

        self.PULL_SOCKET = self.ZMQ_CONTEXT.socket(zmq.PULL)
        self.PULL_SOCKET.setsockopt(zmq.RCVHWM, 1)

        self.SUB_SOCKET = self.ZMQ_CONTEXT.socket(zmq.SUB)

        # Bind PUSH Socket to send commands to MetaTrader
        self.PUSH_SOCKET.connect(self._URL + str(self.PUSH_PORT))
        print("[INIT] Ready to send commands to METATRADER (PUSH): " + str(self.PUSH_PORT))

        # Connect PULL Socket to receive command responses from MetaTrader
        self.PULL_SOCKET.connect(self._URL + str(self.PULL_PORT))
        print("[INIT] Listening for responses from METATRADER (PULL): " + str(self.PULL_PORT))

        # Connect SUB Socket to receive market data from MetaTrader
        print("[INIT] Listening for market data from METATRADER (SUB): " + str(self.SUB_PORT))
        self.SUB_SOCKET.connect(self._URL + str(self.SUB_PORT))

        # Initialize POLL set and register PULL and SUB sockets
        self.POLLER = zmq.Poller()
        self.POLLER.register(self.PULL_SOCKET, zmq.POLLIN)
        self.POLLER.register(self.SUB_SOCKET, zmq.POLLIN)

        #################################################################
        # Start listening for responses to commands and new market data
        # self._string_delimiter = _delimiter
        #################################################################

        # BID/ASK Market Data Subscription Threads ({SYMBOL: Thread})
        self.MARKET_DATA_THREAD = None

        # Begin polling for PULL / SUB data
        self.MARKET_DATA_THREAD = Thread(target=self.pollData)
        self.MARKET_DATA_THREAD.start()

        # Market Data Dictionary by Symbol (holds tick data)
        self.MARKET_DATA_DB = {}  # dict of Pandas dataframe containing tick data

        # Temporary Order STRUCT for convenience wrappers later.
        # self.temp_order_dict = self._generate_default_order_dict()

        # Thread returns the most recently received DATA block here
        self.POLLER_DATA_OUTPUT = {}

        # Verbosity
        self.VERBOSE = VERBOSE

    ############################################
    # Retrieve data from MetaTrader via ZMQ    #
    ############################################
    def remoteReceive(self, socket):

        try:
            msg = socket.recv_string(zmq.DONTWAIT)
            return msg
        except zmq.error.Again:
            print("\nResource timeout during receive.. please try again.")
            sleep(0.000001)

        return None

    ################################
    # Check poller for new data    #
    ################################
    def pollData(self):

        while self.ACTIVE:

            sockets = dict(self.POLLER.poll())
            # Process response to commands sent to MetaTrader
            if self.PULL_SOCKET in sockets and sockets[self.PULL_SOCKET] == zmq.POLLIN:
                try:
                    msg = self.PULL_SOCKET.recv_string(zmq.DONTWAIT)

                    # If data is returned, store as pandas Series
                    if msg != '' and msg != None:

                        try:
                            _data = eval(msg)
                            self.THREAD_DATA_OUTPUT = _data
                            if self.VERBOSE:
                                print(_data)  # default logic

                        except Exception as ex:
                            _exstr = "Exception Type {0}. Args:\n{1!r}"
                            _msg = _exstr.format(type(ex).__name__, ex.args)
                            print(_msg)

                except zmq.error.Again:
                    pass  # resource temporarily unavailable, nothing to print
                except ValueError:
                    pass  # No data returned, passing iteration.
                except UnboundLocalError:
                    pass  # _symbol may sometimes get referenced before being assigned.

            # Receive new market data from MetaTrader
            if self.SUB_SOCKET in sockets and sockets[self.SUB_SOCKET] == zmq.POLLIN:
                print("Test Point 1")
                try:
                    msg = self.SUB_SOCKET.recv_string(zmq.DONTWAIT)
                    print("Test Point 2")
                    if msg != "":
                        print("Test Point 3")
                        msgDict = eval(msg)

                        if self.VERBOSE:
                            print(msgDict)

                        for incomingSymbol in msgDict.keys():
                            # Update Market Data DB
                            if incomingSymbol not in self.MARKET_DATA_DB.keys():
                                self.MARKET_DATA_DB[incomingSymbol] = DataFrame()

                            # Append data to DataFrame corresponding to that symbol
                            self.MARKET_DATA_DB[incomingSymbol].append(
                                DataFrame.from_dict(msgDict['Data'][incomingSymbol])
                            )
                            # Temporary: Remove duplicates
                            for key in self.MARKET_DATA_DB.keys():
                                DataFrame.drop_duplicates(self.MARKET_DATA_DB[key], inplace=True)

                            # To Do:
                            # Implement clean up function to remove duplicates

                except zmq.error.Again:
                    pass  # resource temporarily unavailable, nothing to print
                except ValueError:
                    pass  # No data returned, passing iteration.
                except UnboundLocalError:
                    pass  # _symbol may sometimes get referenced before being assigned.

    ##########################################################################

    ###################################
    # Subscribe to ticks from symbol  #
    ###################################
    def subscribeToSymbolTicks(self, symbol=""):

        # Subscribe to SYMBOL first.
        if symbol != "":
            self.SUB_SOCKET.setsockopt_string(zmq.SUBSCRIBE, symbol)

        if self.MARKET_DATA_THREAD is None:
            self.MARKET_DATA_THREAD = Thread(target=self.pollData())
            self.MARKET_DATA_THREAD.start()

        print("[KERNEL] Subscribed to {} BID/ASK updates. See self.MARKET_DATA_DB.".format(symbol))
