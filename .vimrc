set nocompatible 
syntax on 
set showmatch 
filetype plugin indent on " Enable file type detection and load plugins/indentation rules for specific file types
set autoindent " Keep the same indent as the previous line when starting a new line
set smartindent " Each line has the same indent amount as the previous line 

set background=dark 
set encoding=utf-8 nobomb 
set ttyfast 
highlight Comment ctermfg=2 guifg=#839496

set nobackup 
set showmode 
set laststatus=2 " Always show the status line (0=never, 1=only if more than one window, 2=always)
set backspace=indent,eol,start " Allow backspace in insert mode
set timeout timeoutlen=1000 ttimeoutlen=50 " Fix slow <Esc> in insert mode with mappings, and mapping timeout
set nu 
set rnu 
set hls 
set history=8192 
set incsearch 
set showcmd 
set ruler
" set cursorline 

"set lcs=tab:▸\ ,trail:·,eol:¬,nbsp:_  " Show invisible characters
"set list 

set ignorecase " Ignore case when searching
set smartcase " Override 'ignorecase' if the search pattern contains uppercase letters

" Tab completion for files/buffers
set wildmode=longest:list,full " Completion mode for wildmenu:
set wildmenu " Display a command-line completion menu
set mouse+=a " Enable mouse mode in all modes (scrolling, selection, window resizing, etc.)

if &term =~ '^screen' || &term =~ '^tmux' 
    set ttymouse=xterm2 
endif
set nofoldenable " Disable code folding by default

" Use spaces instead of tabs
set expandtab " Insert spaces when Tab key is pressed
set tabstop=4 " Number of spaces that a Tab in the file counts for
set shiftwidth=4 " Number of spaces to use for autoindent and shifting commands (<<, >>)
set softtabstop=4 " Number of spaces that Tab_key inserts/deletes in insert mode

set clipboard=unnamedplus " Use the system clipboard for all yank, delete, change, and put operations.

" For leader shortcut
let mapleader = " " 
nnoremap <Leader>q :q<CR> 
nnoremap <Leader>w :w<CR> 
nnoremap <Leader>wq :wq<CR> 

map <C-K> <C-V> " Map Ctrl-K to start visual block mode (Ctrl-V)
inoremap jk <Esc> 
inoremap vv <Esc> 

