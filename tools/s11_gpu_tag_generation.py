"""S11 variant of openfpga-PlayStation's gpu_tag_generation patch.

Derived from scripts/prepare_gpu_tag_generation.py (GPL-2.0). S11's texture-cache tag is 11 bits wide
(upstream: 10), so the tag RAM becomes 19 bits (8-bit generation + 11-bit tag). Everything else is
unchanged: the 256 valid flip-flops become a generation stored with each tag.
"""


def _replace(text, old, new, count=1):
    if text.count(old) != count:
        raise ValueError(f'gpu_pixelpipeline changed ({text.count(old)} matches): ' + old.strip()[:70])
    return text.replace(old, new)


def tag_generation_text(text, bits=8):
    """bits < 8 is for tests: the generation wraps sooner, exercising CLEARTAGS."""
    top = f'x"{(1 << bits) - 1:02X}"'
    text = _replace(text, '   type t_filterarray_b11 is array(0 to 3) of std_logic_vector(10 downto 0);\n',
                    '   type t_filterarray_b11 is array(0 to 3) of std_logic_vector(10 downto 0);\n'
                    '   type t_filterarray_b19 is array(0 to 3) of std_logic_vector(18 downto 0);\n')
    text = _replace(text, '   signal tag_data_a          : std_logic_vector(10 downto 0) := (others => \'0\');\n',
                    '   signal tag_data_a          : std_logic_vector(18 downto 0) := (others => \'0\');\n')
    text = _replace(text, '   signal tag_q_b             : t_filterarray_b11;\n', '   signal tag_q_b             : t_filterarray_b19;\n')
    text = _replace(text, '   signal tagValid            : std_logic_vector(0 to 255) := (others => \'0\');\n',
                    '''   -- Tag generation: an entry is valid when its stored generation is current.
   signal tagGeneration       : unsigned(7 downto 0) := x"01";
   signal clearAddress        : unsigned(7 downto 0) := (others => '0');
''')
    text = _replace(text, '''         width                               => 11,
         widthad                             => 8''', '''         width                               => 19,
         widthad                             => 8''')
    text = _replace(text, "      cachehit(i)        <= '1' when (unsigned(tag_q_b(i)) = tag_data(i) and tagValid(to_integer(tag_addr(i))) = '1') else '0';",
                    "      cachehit(i)        <= '1' when (unsigned(tag_q_b(i)(10 downto 0)) = tag_data(i) and unsigned(tag_q_b(i)(18 downto 11)) = tagGeneration) else '0';")
    text = _replace(text, '''               tag_wren_a    <= '1';
               tagValid(to_integer(tag_address_a)) <= '1';
''', '''               tag_wren_a    <= '1';
''')
    text = _replace(text, '''                  if (clearCacheBuffer = '1' and pipeline_busy = '0') then
                     clearCacheBuffer <= '0';
                     tagValid         <= (others => '0');
                  end if;
                  if (textPalReq = '1' and pipeline_busy = '0') then''', '''                  if (clearCacheBuffer = '1' and pipeline_busy = '0') then
                     clearCacheBuffer <= '0';
                     if (tagGeneration = __GENTOP__) then
                        tagGeneration <= x"01";
                        clearAddress  <= (others => '0');
                        state         <= CLEARTAGS;
                     else
                        tagGeneration <= tagGeneration + 1;
                     end if;
                  end if;
                  if (clearCacheBuffer = '1' and pipeline_busy = '0' and tagGeneration = __GENTOP__) then
                     null; -- the tag clear runs first; other requests wait for IDLE
                  elsif (textPalReq = '1' and pipeline_busy = '0') then''')
    text = _replace(text, "                     tag_data_a      <= std_logic_vector(tag_data(0));\n",
                    "                     tag_data_a      <= std_logic_vector(tagGeneration) & std_logic_vector(tag_data(0));\n")
    text = _replace(text, "                  tag_data_a      <= std_logic_vector(tag_data_1(selectIndex));\n",
                    "                  tag_data_a      <= std_logic_vector(tagGeneration) & std_logic_vector(tag_data_1(selectIndex));\n")
    text = _replace(text, '''               when WAITTEXTURE => null; -- handled outside due to ce
''', '''               when WAITTEXTURE => null; -- handled outside due to ce

               when CLEARTAGS =>
                  tag_wren_a    <= '1';
                  tag_address_a <= clearAddress;
                  tag_data_a    <= (others => '0');
                  clearAddress  <= clearAddress + 1;
                  if (clearAddress = x"FF") then
                     state <= IDLE;
                  end if;
''')
    import re
    states = re.search(r'type tState is\s*\(\s*IDLE,', text)
    if not states: raise ValueError('gpu_pixelpipeline state type changed')
    text = text[:states.end()] + '\n      CLEARTAGS,' + text[states.end():]
    text = text.replace('__GENTOP__', top)
    if 'tagValid' in text: raise ValueError('A tag valid access remains')
    return text


