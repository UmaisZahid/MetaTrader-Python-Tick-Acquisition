# MetaTrader-Python-Tick-Acquisition
MetaTrader5  to Python Bridge, with millisecond level tick precision.
Based off Darwinex ZeroMQ MT4 bridge. 

# To Do: 
- Complete transition to MT5
- Create pipeline to store live ticks into database storage


# Completed:
- Added millisecond level tick precision. 
- Converting message format to JSON
- Convert tick data to OHLC (candlestick) on pandas and compare with original broker historical data. 
  Note: MT4/5 seems to be dropping a non-insignificant portion of the ticks. Unfortunately, this seems to be a limitation of MetaTrader itself. 
  
